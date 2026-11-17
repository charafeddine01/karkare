<?php
declare(strict_types=1);

namespace CarLog\Controllers;

use CarLog\Config\Config;
use CarLog\Config\Database;
use CarLog\Router\Request;
use CarLog\Router\Response;
use PDO;
use Throwable;

class VehicleController {
    private PDO $db;
    private string $driver;

    public function __construct() {
        $this->db = Database::getConnection();
        $this->driver = Database::getDriver();
    }

    private function generateUuid(): string {
        $data = random_bytes(16);
        $data[6] = chr(ord($data[6]) & 0x0f | 0x40); // UUID v4
        $data[8] = chr(ord($data[8]) & 0x3f | 0x80);
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }

    /**
     * Resolves and verifies a valid vehicle ID for the user
     * Prevents foreign key constraint violations across child tables
     */
    private function getValidVehicleId(string $userId, ?string $candidateId): string {
        if (!empty($candidateId) && $candidateId !== 'undefined' && $candidateId !== 'null') {
            $stmt = $this->db->prepare("SELECT id FROM vehicles WHERE id = ? AND user_id = ? AND is_deleted = 0");
            $stmt->execute([$candidateId, $userId]);
            $veh = $stmt->fetch();
            if ($veh) {
                return (string)$veh['id'];
            }

            // Also check if vehicle exists for user even if is_deleted = 1 (restore active status)
            $stmtDel = $this->db->prepare("SELECT id FROM vehicles WHERE id = ? AND user_id = ?");
            $stmtDel->execute([$candidateId, $userId]);
            $vehDel = $stmtDel->fetch();
            if ($vehDel) {
                $this->db->prepare("UPDATE vehicles SET is_deleted = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?")->execute([$candidateId, $userId]);
                return (string)$vehDel['id'];
            }
        }

        // Fallback to latest active vehicle for this user
        $stmt = $this->db->prepare("SELECT id FROM vehicles WHERE user_id = ? AND is_deleted = 0 ORDER BY updated_at DESC LIMIT 1");
        $stmt->execute([$userId]);
        $veh = $stmt->fetch();
        if ($veh) {
            return (string)$veh['id'];
        }

        // Only seed demo vehicle for the demo account
        if ($userId === 'd0000000-0000-0000-0000-000000000001') {
            $this->seedInitialUserVehicle($userId);
            $stmt->execute([$userId]);
            $veh = $stmt->fetch();
            if ($veh) {
                return (string)$veh['id'];
            }
        }

        throw new RuntimeException("No active vehicle found in your garage. Please add a vehicle first.");
    }

    /**
     * Get entire garage dashboard payload for user
     */
    public function getGarage(Request $request): void {
        $userId = $request->getUserId();

        try {
            // 1. Fetch user's vehicles
            $stmt = $this->db->prepare("SELECT * FROM vehicles WHERE user_id = ? AND is_deleted = 0 ORDER BY updated_at DESC");
            $stmt->execute([$userId]);
            $vehicles = $stmt->fetchAll();

            // Only seed initial demo vehicle for the demo account
            if (empty($vehicles) && $userId === 'd0000000-0000-0000-0000-000000000001') {
                $this->seedInitialUserVehicle($userId);
                $stmt->execute([$userId]);
                $vehicles = $stmt->fetchAll();
            }

            $activeVehicleId = $request->getQuery('vehicle_id');
            if (empty($activeVehicleId) || !in_array($activeVehicleId, array_column($vehicles, 'id'), true)) {
                $activeVehicleId = $vehicles[0]['id'] ?? null;
            }

            $activeVehicle = null;
            $quickSpecs = null;
            $visits = [];
            $fuelLogs = [];
            $symptoms = [];
            $trips = [];
            $expenses = [];
            $rawReminders = [];
            $remindersUpcoming = [];
            $remindersOverdue = [];
            $remindersCompleted = [];
            $predictiveDecay = [];

            if ($activeVehicleId) {
                // Find active vehicle object
                foreach ($vehicles as $v) {
                    if ($v['id'] === $activeVehicleId) {
                        $activeVehicle = $v;
                        break;
                    }
                }

                // Quick Specs
                $stmtSpecs = $this->db->prepare("SELECT * FROM vehicle_quick_specs WHERE vehicle_id = ? LIMIT 1");
                $stmtSpecs->execute([$activeVehicleId]);
                $quickSpecs = $stmtSpecs->fetch() ?: null;

                // Service Visits & Logs
                $stmtVisits = $this->db->prepare(
                    "SELECT sv.*, cd.shop_name 
                     FROM service_visits sv 
                     LEFT JOIN contacts_directory cd ON sv.contact_id = cd.id 
                     WHERE sv.vehicle_id = ? AND sv.is_deleted = 0 
                     ORDER BY sv.service_date DESC, sv.odometer_km DESC"
                );
                $stmtVisits->execute([$activeVehicleId]);
                $rawVisits = $stmtVisits->fetchAll();

                $stmtLogs = $this->db->prepare(
                    "SELECT ml.*, mtt.task_name, mtt.category as task_category 
                     FROM maintenance_logs ml 
                     LEFT JOIN maintenance_tasks_template mtt ON ml.task_id = mtt.id 
                     WHERE ml.vehicle_id = ? AND ml.is_deleted = 0 
                     ORDER BY ml.service_date DESC"
                );
                $stmtLogs->execute([$activeVehicleId]);
                $rawLogs = $stmtLogs->fetchAll();

                // Group logs under visits
                $logsByVisit = [];
                foreach ($rawLogs as $log) {
                    $vId = $log['visit_id'] ?: 'standalone';
                    $logsByVisit[$vId][] = $log;
                }

                foreach ($rawVisits as $visit) {
                    $visitLogs = $logsByVisit[$visit['id']] ?? [];
                    $totalParts = 0.0;
                    $totalLabor = 0.0;
                    foreach ($visitLogs as $l) {
                        $totalParts += (float)($l['cost_parts_usd'] ?? 0);
                        $totalLabor += (float)($l['cost_labor_usd'] ?? 0);
                    }
                    $visit['total_cost_usd'] = $totalParts + $totalLabor;
                    $visit['tasks'] = $visitLogs;
                    $visits[] = $visit;
                }

                // Fuel Logs
                $stmtFuel = $this->db->prepare(
                    "SELECT * FROM fuel_logs WHERE vehicle_id = ? AND is_deleted = 0 ORDER BY fill_date DESC, odometer_km DESC"
                );
                $stmtFuel->execute([$activeVehicleId]);
                $fuelLogs = $stmtFuel->fetchAll();

                // Symptoms
                $stmtSymptoms = $this->db->prepare(
                    "SELECT * FROM diagnostic_symptoms WHERE vehicle_id = ? AND is_deleted = 0 ORDER BY logged_date DESC"
                );
                $stmtSymptoms->execute([$activeVehicleId]);
                $symptoms = $stmtSymptoms->fetchAll();

                // Trip Logs (KM & Purpose Tracking)
                $stmtTrips = $this->db->prepare(
                    "SELECT * FROM trip_logs WHERE vehicle_id = ? AND is_deleted = 0 ORDER BY trip_date DESC, trip_time DESC"
                );
                $stmtTrips->execute([$activeVehicleId]);
                $trips = $stmtTrips->fetchAll();

                // General Expenses (Parking, Toll, Wash, Fine, Insurance)
                $stmtExpenses = $this->db->prepare(
                    "SELECT * FROM general_expenses WHERE vehicle_id = ? AND is_deleted = 0 ORDER BY expense_date DESC, expense_time DESC"
                );
                $stmtExpenses->execute([$activeVehicleId]);
                $expenses = $stmtExpenses->fetchAll();

                // Vehicle Reminders (Upcoming, Overdue, Completed)
                $stmtReminders = $this->db->prepare(
                    "SELECT * FROM vehicle_reminders WHERE vehicle_id = ? AND is_deleted = 0 ORDER BY is_completed ASC, due_date ASC"
                );
                $stmtReminders->execute([$activeVehicleId]);
                $rawReminders = $stmtReminders->fetchAll();

                // Split reminders and calculate remaining days/km
                $today = date('Y-m-d');
                $currentVehOdo = (int)($activeVehicle['current_odometer_km'] ?? 0);
                $remindersUpcoming = [];
                $remindersOverdue = [];
                $remindersCompleted = [];

                foreach ($rawReminders as $rem) {
                    $dueDate = $rem['due_date'];
                    $dueKm = !empty($rem['due_odometer_km']) ? (int)$rem['due_odometer_km'] : null;
                    $isCompleted = (int)($rem['is_completed'] ?? 0) === 1;

                    $daysDiff = null;
                    if ($dueDate) {
                        $dueTs = strtotime($dueDate);
                        $todayTs = strtotime($today);
                        $daysDiff = (int)round(($dueTs - $todayTs) / 86400);
                    }

                    $kmDiff = null;
                    if ($dueKm !== null) {
                        $kmDiff = $dueKm - $currentVehOdo;
                    }

                    $rem['days_diff'] = $daysDiff;
                    $rem['km_diff'] = $kmDiff;

                    if ($isCompleted) {
                        $remindersCompleted[] = $rem;
                    } elseif (($daysDiff !== null && $daysDiff < 0) || ($kmDiff !== null && $kmDiff < 0)) {
                        $rem['overdue_days'] = $daysDiff !== null ? abs($daysDiff) : 0;
                        $rem['overdue_km'] = $kmDiff !== null ? abs($kmDiff) : 0;
                        $remindersOverdue[] = $rem;
                    } else {
                        $remindersUpcoming[] = $rem;
                    }
                }

                // Calculate Predictive Fluid & Wear Decay
                $predictiveDecay = $this->calculatePredictiveDecay($activeVehicle, $rawLogs);
            }

            // Inventory
            $stmtInv = $this->db->prepare("SELECT * FROM garage_inventory WHERE user_id = ? AND is_deleted = 0 ORDER BY item_name ASC");
            $stmtInv->execute([$userId]);
            $inventory = $stmtInv->fetchAll();

            // Contacts
            $stmtContacts = $this->db->prepare("SELECT * FROM contacts_directory WHERE user_id = ? AND is_deleted = 0 ORDER BY shop_name ASC");
            $stmtContacts->execute([$userId]);
            $contacts = $stmtContacts->fetchAll();

            // Task Templates
            $stmtTasks = $this->db->query("SELECT * FROM maintenance_tasks_template WHERE is_deleted = 0 ORDER BY category, task_name ASC");
            $tasks = $stmtTasks->fetchAll();

            // Financial Calculations
            $totalMaintenanceCost = 0.0;
            foreach ($visits as $v) {
                $totalMaintenanceCost += (float)($v['total_cost_usd'] ?? 0);
            }
            $totalFuelCost = 0.0;
            $totalFuelLiters = 0.0;
            foreach ($fuelLogs as $fl) {
                $totalFuelCost += (float)($fl['total_cost_usd'] ?? 0);
                $totalFuelLiters += (float)($fl['fuel_liters'] ?? 0);
            }
            $totalExpensesCost = 0.0;
            foreach ($expenses as $ex) {
                $totalExpensesCost += (float)($ex['amount_usd'] ?? 0);
            }

            $totalSpent = $totalMaintenanceCost + $totalFuelCost + $totalExpensesCost;

            // Distance calculation
            $tripsDistance = 0.0;
            foreach ($trips as $t) {
                $tripsDistance += (float)$t['distance_km'];
            }
            $currentOdo = (int)($activeVehicle['current_odometer_km'] ?? 0);
            $acqOdo = (int)($activeVehicle['acquisition_odometer_km'] ?? 0);
            $drivenDistance = $activeVehicle ? max(0, $currentOdo - $acqOdo) : 0;
            $displayDistanceKm = $tripsDistance > 0 ? $tripsDistance : (float)$drivenDistance;

            $costPerKm = $displayDistanceKm > 0 ? ($totalSpent / $displayDistanceKm) : 0;

            // Build Chronological Unified History Feed
            $historyFeed = [];
            foreach ($trips as $tr) {
                $historyFeed[] = [
                    'id' => $tr['id'],
                    'type' => 'trip',
                    'date' => $tr['trip_date'],
                    'time' => $tr['trip_time'] ?? '12:00:00',
                    'datetime' => $tr['trip_date'] . ' ' . ($tr['trip_time'] ?? '12:00:00'),
                    'title' => 'TRIP LOG',
                    'badge' => round((float)$tr['distance_km'], 1) . ' km • ' . $tr['purpose'],
                    'amount_usd' => 0.0,
                    'distance_km' => (float)$tr['distance_km'],
                    'details' => $tr,
                ];
            }
            foreach ($fuelLogs as $fl) {
                $dt = $fl['fill_date'];
                $datePart = substr($dt, 0, 10);
                $timePart = strlen($dt) > 10 ? substr($dt, 11, 8) : '12:00:00';
                $l = (float)$fl['fuel_liters'];
                $ppl = (float)$fl['price_per_liter_usd'];
                $historyFeed[] = [
                    'id' => $fl['id'],
                    'type' => 'fuel',
                    'date' => $datePart,
                    'time' => $timePart,
                    'datetime' => $datePart . ' ' . $timePart,
                    'title' => 'FUEL LOG',
                    'badge' => round($l, 1) . ' L • ' . round($ppl, 2) . ' USD /L',
                    'amount_usd' => (float)$fl['total_cost_usd'],
                    'distance_km' => 0.0,
                    'details' => $fl,
                ];
            }
            foreach ($expenses as $ex) {
                $historyFeed[] = [
                    'id' => $ex['id'],
                    'type' => 'expense',
                    'date' => $ex['expense_date'],
                    'time' => $ex['expense_time'] ?? '12:00:00',
                    'datetime' => $ex['expense_date'] . ' ' . ($ex['expense_time'] ?? '12:00:00'),
                    'title' => 'EXPENSE',
                    'badge' => $ex['expense_type'] . ' • ' . round((float)$ex['amount_usd'], 2) . ' USD',
                    'amount_usd' => (float)$ex['amount_usd'],
                    'distance_km' => 0.0,
                    'details' => $ex,
                ];
            }
            foreach ($visits as $vs) {
                $taskSummary = !empty($vs['tasks']) ? implode(', ', array_slice(array_column($vs['tasks'], 'task_name'), 0, 2)) : ($vs['visit_title'] ?? 'Workshop Visit');
                $historyFeed[] = [
                    'id' => $vs['id'],
                    'type' => 'maintenance',
                    'date' => $vs['service_date'],
                    'time' => '12:00:00',
                    'datetime' => $vs['service_date'] . ' 12:00:00',
                    'title' => 'MAINTENANCE',
                    'badge' => $taskSummary . ' • ' . round((float)($vs['total_cost_usd'] ?? 0), 2) . ' USD',
                    'amount_usd' => (float)($vs['total_cost_usd'] ?? 0),
                    'distance_km' => 0.0,
                    'details' => $vs,
                ];
            }
            usort($historyFeed, fn($a, $b) => strcmp($b['datetime'], $a['datetime']));

            // Fleet Overview Aggregations across all user vehicles
            $fleetTotalDistance = 0;
            $fleetTotalFuelLiters = 0.0;
            $fleetTotalFuelKm = 0;
            foreach ($vehicles as $veh) {
                $vCur = (int)($veh['current_odometer_km'] ?? 0);
                $vAcq = (int)($veh['acquisition_odometer_km'] ?? 0);
                $fleetTotalDistance += max(0, $vCur - $vAcq);
            }
            $fleetAvgConsumption = $displayDistanceKm > 0 && $totalFuelLiters > 0 
                ? round(($totalFuelLiters / $displayDistanceKm) * 100, 1) 
                : 5.4;

            // Monthly Cost over Time Trend series
            $monthlySpending = [];
            foreach ($historyFeed as $item) {
                $m = substr($item['date'], 0, 7);
                $monthlySpending[$m] = ($monthlySpending[$m] ?? 0.0) + (float)$item['amount_usd'];
            }
            ksort($monthlySpending);
            $costOverTime = [];
            foreach ($monthlySpending as $monthKey => $monthSum) {
                $costOverTime[] = [
                    'period' => $monthKey,
                    'amount_usd' => round($monthSum, 2),
                ];
            }

            Response::success([
                'vehicles' => $vehicles,
                'active_vehicle_id' => $activeVehicleId,
                'active_vehicle' => $activeVehicle,
                'quick_specs' => $quickSpecs,
                'visits' => $visits,
                'fuel_logs' => $fuelLogs,
                'symptoms' => $symptoms,
                'trips' => $trips,
                'expenses' => $expenses,
                'reminders' => [
                    'upcoming' => $remindersUpcoming,
                    'overdue' => $remindersOverdue,
                    'completed' => $remindersCompleted,
                    'all' => $rawReminders,
                ],
                'history' => $historyFeed,
                'inventory' => $inventory,
                'contacts' => $contacts,
                'tasks' => $tasks,
                'predictive_decay' => $predictiveDecay,
                'fleet' => [
                    'total_vehicles' => count($vehicles),
                    'total_distance_km' => $fleetTotalDistance > 0 ? $fleetTotalDistance : (int)$displayDistanceKm,
                    'avg_consumption_l_per_100km' => $fleetAvgConsumption,
                    'limit_vehicles' => 5,
                ],
                'reports' => [
                    'total_spent_usd' => round($totalSpent, 1),
                    'fuel_cost_usd' => round($totalFuelCost, 1),
                    'maintenance_cost_usd' => round($totalMaintenanceCost, 1),
                    'expenses_cost_usd' => round($totalExpensesCost, 1),
                    'distance_km' => round($displayDistanceKm, 0),
                    'cost_per_km_usd' => round($costPerKm, 1),
                    'cost_over_time' => $costOverTime,
                ],
                'stats' => [
                    'total_maintenance_usd' => round($totalMaintenanceCost, 2),
                    'total_fuel_usd' => round($totalFuelCost, 2),
                    'total_expenses_usd' => round($totalExpensesCost, 2),
                    'total_ownership_usd' => round($totalSpent, 2),
                    'driven_distance_km' => $displayDistanceKm,
                    'cost_per_km_usd' => round($costPerKm, 2),
                    'total_visits_count' => count($visits),
                    'active_symptoms_count' => count(array_filter($symptoms, fn($s) => (int)$s['is_resolved'] === 0)),
                    'overdue_reminders_count' => count($remindersOverdue),
                ]
            ], 'Garage payload loaded successfully.');

        } catch (Throwable $e) {
            error_log("getGarage failed: " . $e->getMessage() . "\n" . $e->getTraceAsString());
            Response::error('Failed to load garage: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Create a new vehicle
     */
    public function createVehicle(Request $request): void {
        $userId = $request->getUserId();
        $b = $request->getBody();

        if (empty($b['make']) || empty($b['model']) || empty($b['year'])) {
            Response::error('Make, Model, and Year are required', 'VALIDATION_ERROR', 400);
            return;
        }

        $id = !empty($b['id']) ? (string)$b['id'] : $this->generateUuid();
        $shareToken = bin2hex(random_bytes(20));

        try {
            $stmt = $this->db->prepare(
                "INSERT INTO vehicles (
                    id, user_id, vehicle_type, vin, plate_number, make, model, year,
                    engine_displacement_cc, engine_code, power_kw, transmission_type,
                    fuel_type, acquisition_odometer_km, current_odometer_km, photo_url,
                    public_share_token, hide_costs_on_share, is_deleted
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?,
                    ?, ?, ?, ?,
                    ?, ?, 0
                )"
            );

            $stmt->execute([
                $id,
                $userId,
                $b['vehicle_type'] ?? 'car',
                !empty($b['vin']) ? strtoupper(trim((string)$b['vin'])) : null,
                !empty($b['plate_number']) ? trim((string)$b['plate_number']) : null,
                trim((string)$b['make']),
                trim((string)$b['model']),
                (int)$b['year'],
                !empty($b['engine_displacement_cc']) ? (int)$b['engine_displacement_cc'] : null,
                !empty($b['engine_code']) ? trim((string)$b['engine_code']) : null,
                !empty($b['power_kw']) ? (int)$b['power_kw'] : null,
                $b['transmission_type'] ?? 'manual',
                $b['fuel_type'] ?? 'gasoline',
                (int)($b['acquisition_odometer_km'] ?? 0),
                (int)($b['current_odometer_km'] ?? ($b['acquisition_odometer_km'] ?? 0)),
                $b['photo_url'] ?? null,
                $shareToken,
                (int)($b['hide_costs_on_share'] ?? 1),
            ]);

            // Create initial default quick specs
            $stmtSpecs = $this->db->prepare(
                "INSERT INTO vehicle_quick_specs (vehicle_id, oil_viscosity, oil_capacity_l, front_tire_pressure_bar, rear_tire_pressure_bar, wheel_lug_torque_nm)
                 VALUES (?, ?, ?, ?, ?, ?)"
            );
            $stmtSpecs->execute([
                $id,
                $b['oil_viscosity'] ?? '5W-30 Full Synthetic',
                !empty($b['oil_capacity_l']) ? (float)$b['oil_capacity_l'] : 4.20,
                !empty($b['front_tire_pressure_bar']) ? (float)$b['front_tire_pressure_bar'] : 2.30,
                !empty($b['rear_tire_pressure_bar']) ? (float)$b['rear_tire_pressure_bar'] : 2.20,
                !empty($b['wheel_lug_torque_nm']) ? (int)$b['wheel_lug_torque_nm'] : 103,
            ]);

            Response::success([
                'id' => $id,
                'make' => $b['make'],
                'model' => $b['model'],
                'year' => (int)$b['year'],
                'public_share_token' => $shareToken,
            ], 'Vehicle registered successfully.', 201);

        } catch (Throwable $e) {
            error_log("createVehicle error: " . $e->getMessage());
            Response::error('Failed to create vehicle: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Update existing vehicle
     */
    public function updateVehicle(Request $request): void {
        $userId = $request->getUserId();
        $id = $request->getParam('id');
        $b = $request->getBody();

        try {
            $stmt = $this->db->prepare(
                "UPDATE vehicles SET
                    vehicle_type = COALESCE(?, vehicle_type),
                    vin = COALESCE(?, vin),
                    plate_number = COALESCE(?, plate_number),
                    make = COALESCE(?, make),
                    model = COALESCE(?, model),
                    year = COALESCE(?, year),
                    engine_displacement_cc = COALESCE(?, engine_displacement_cc),
                    engine_code = COALESCE(?, engine_code),
                    power_kw = COALESCE(?, power_kw),
                    transmission_type = COALESCE(?, transmission_type),
                    fuel_type = COALESCE(?, fuel_type),
                    current_odometer_km = COALESCE(?, current_odometer_km),
                    photo_url = COALESCE(?, photo_url)
                 WHERE id = ? AND user_id = ?"
            );

            $stmt->execute([
                $b['vehicle_type'] ?? null,
                $b['vin'] ?? null,
                $b['plate_number'] ?? null,
                $b['make'] ?? null,
                $b['model'] ?? null,
                !empty($b['year']) ? (int)$b['year'] : null,
                !empty($b['engine_displacement_cc']) ? (int)$b['engine_displacement_cc'] : null,
                $b['engine_code'] ?? null,
                !empty($b['power_kw']) ? (int)$b['power_kw'] : null,
                $b['transmission_type'] ?? null,
                $b['fuel_type'] ?? null,
                !empty($b['current_odometer_km']) ? (int)$b['current_odometer_km'] : null,
                $b['photo_url'] ?? null,
                $id,
                $userId,
            ]);

            Response::success(['id' => $id], 'Vehicle updated successfully.');
        } catch (Throwable $e) {
            Response::error('Failed to update vehicle: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Soft-delete vehicle
     */
    public function deleteVehicle(Request $request): void {
        $userId = $request->getUserId();
        $id = $request->getParam('id');

        if (empty($id)) {
            Response::error('Vehicle ID required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            // Verify vehicle exists and belongs to user
            $stmt = $this->db->prepare("SELECT id FROM vehicles WHERE id = ? AND user_id = ? AND is_deleted = 0");
            $stmt->execute([$id, $userId]);
            if (!$stmt->fetch()) {
                Response::error('Vehicle not found or already deleted', 'NOT_FOUND', 404);
                return;
            }

            // Soft-delete vehicle
            $stmtDel = $this->db->prepare("UPDATE vehicles SET is_deleted = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?");
            $stmtDel->execute([$id, $userId]);

            Response::success(['id' => $id], 'Vehicle deleted successfully.');
        } catch (Throwable $e) {
            Response::error('Failed to delete vehicle: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Update vehicle photo URL directly
     */
    public function updateVehiclePhoto(Request $request): void {
        $userId = $request->getUserId();
        $rawId = $request->getParam('id') ?: ($request->get('vehicle_id') ?: null);
        $b = $request->getBody();

        $photoUrl = trim((string)($b['photo_url'] ?? $request->get('photo_url', '')));
        if (empty($photoUrl)) {
            Response::error('photo_url is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            // Verify and resolve valid vehicle owned by this user
            $vehicleId = $this->getValidVehicleId($userId, $rawId);

            $stmtUpdate = $this->db->prepare("UPDATE vehicles SET photo_url = ?, is_deleted = 0, updated_at = CURRENT_TIMESTAMP WHERE id = ? AND user_id = ?");
            $stmtUpdate->execute([$photoUrl, $vehicleId, $userId]);

            Response::success([
                'id' => $vehicleId,
                'photo_url' => $photoUrl
            ], 'Vehicle photo updated.');
        } catch (Throwable $e) {
            Response::error('Failed to update photo: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Save / Update Glovebox Quick Specs
     */
    public function saveQuickSpecs(Request $request): void {
        $userId = $request->getUserId();
        $vehicleId = $request->getParam('id');
        $b = $request->getBody();

        try {
            $q = $this->driver === 'sqlite'
                ? "INSERT OR REPLACE INTO vehicle_quick_specs (
                    vehicle_id, oil_viscosity, oil_capacity_l, coolant_spec, coolant_capacity_l,
                    front_tire_size, rear_tire_size, front_tire_pressure_bar, rear_tire_pressure_bar,
                    wiper_driver_mm, wiper_passenger_mm, wiper_rear_mm, battery_spec,
                    spark_plug_gap_mm, wheel_lug_torque_nm, chain_pitch_mm, updated_at
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)"
                : "INSERT INTO vehicle_quick_specs (
                    vehicle_id, oil_viscosity, oil_capacity_l, coolant_spec, coolant_capacity_l,
                    front_tire_size, rear_tire_size, front_tire_pressure_bar, rear_tire_pressure_bar,
                    wiper_driver_mm, wiper_passenger_mm, wiper_rear_mm, battery_spec,
                    spark_plug_gap_mm, wheel_lug_torque_nm, chain_pitch_mm, updated_at
                   ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP(3))
                   ON DUPLICATE KEY UPDATE
                    oil_viscosity = VALUES(oil_viscosity),
                    oil_capacity_l = VALUES(oil_capacity_l),
                    coolant_spec = VALUES(coolant_spec),
                    coolant_capacity_l = VALUES(coolant_capacity_l),
                    front_tire_size = VALUES(front_tire_size),
                    rear_tire_size = VALUES(rear_tire_size),
                    front_tire_pressure_bar = VALUES(front_tire_pressure_bar),
                    rear_tire_pressure_bar = VALUES(rear_tire_pressure_bar),
                    wiper_driver_mm = VALUES(wiper_driver_mm),
                    wiper_passenger_mm = VALUES(wiper_passenger_mm),
                    wiper_rear_mm = VALUES(wiper_rear_mm),
                    battery_spec = VALUES(battery_spec),
                    spark_plug_gap_mm = VALUES(spark_plug_gap_mm),
                    wheel_lug_torque_nm = VALUES(wheel_lug_torque_nm),
                    chain_pitch_mm = VALUES(chain_pitch_mm),
                    updated_at = CURRENT_TIMESTAMP(3)";

            $stmt = $this->db->prepare($q);
            $stmt->execute([
                $vehicleId,
                $b['oil_viscosity'] ?? null,
                !empty($b['oil_capacity_l']) ? (float)$b['oil_capacity_l'] : null,
                $b['coolant_spec'] ?? null,
                !empty($b['coolant_capacity_l']) ? (float)$b['coolant_capacity_l'] : null,
                $b['front_tire_size'] ?? null,
                $b['rear_tire_size'] ?? null,
                !empty($b['front_tire_pressure_bar']) ? (float)$b['front_tire_pressure_bar'] : null,
                !empty($b['rear_tire_pressure_bar']) ? (float)$b['rear_tire_pressure_bar'] : null,
                !empty($b['wiper_driver_mm']) ? (int)$b['wiper_driver_mm'] : null,
                !empty($b['wiper_passenger_mm']) ? (int)$b['wiper_passenger_mm'] : null,
                !empty($b['wiper_rear_mm']) ? (int)$b['wiper_rear_mm'] : null,
                $b['battery_spec'] ?? null,
                !empty($b['spark_plug_gap_mm']) ? (float)$b['spark_plug_gap_mm'] : null,
                !empty($b['wheel_lug_torque_nm']) ? (int)$b['wheel_lug_torque_nm'] : null,
                $b['chain_pitch_mm'] ?? null,
            ]);

            Response::success(['vehicle_id' => $vehicleId], 'Quick specs saved.');
        } catch (Throwable $e) {
            Response::error('Failed to save specs: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Create a Multi-Task Service Bundle Visit
     */
    public function createServiceVisit(Request $request): void {
        $userId = $request->getUserId();
        $b = $request->getBody();

        if (empty($b['service_date']) || !isset($b['odometer_km'])) {
            Response::error('Service Date and Odometer are required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $vehicleId = $this->getValidVehicleId($userId, $b['vehicle_id'] ?? null);
            $visitId = !empty($b['id']) ? (string)$b['id'] : $this->generateUuid();
            $odometerKm = (int)$b['odometer_km'];
            $tasks = $b['tasks'] ?? [];

            $this->db->beginTransaction();

            // Check or create workshop contact if shop_name provided
            $contactId = $b['contact_id'] ?? null;
            if (empty($contactId) && !empty($b['shop_name'])) {
                $contactId = $this->generateUuid();
                $stmtC = $this->db->prepare(
                    "INSERT INTO contacts_directory (id, user_id, shop_name, specialty) VALUES (?, ?, ?, 'mechanic')"
                );
                $stmtC->execute([$contactId, $userId, trim((string)$b['shop_name'])]);
            }

            // 1. Insert Service Visit
            $stmtVisit = $this->db->prepare(
                "INSERT INTO service_visits (id, vehicle_id, contact_id, service_date, odometer_km, visit_title, receipt_photo_url, notes, is_deleted)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)"
            );
            $stmtVisit->execute([
                $visitId,
                $vehicleId,
                $contactId,
                $b['service_date'],
                $odometerKm,
                $b['visit_title'] ?? 'Workshop Visit',
                $b['receipt_photo_url'] ?? null,
                $b['notes'] ?? null,
            ]);

            // 2. Insert Tasks in maintenance_logs
            $stmtLog = $this->db->prepare(
                "INSERT INTO maintenance_logs (
                    id, visit_id, vehicle_id, task_id, contact_id, service_date, odometer_km,
                    cost_parts_usd, cost_labor_usd, part_brand, part_number, fluid_volume_l,
                    wheel_positions, tire_dot_code, measurement_mm, warranty_expires_date, notes,
                    next_due_km, next_due_date, is_deleted
                ) VALUES (
                    ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?,
                    ?, ?, 0
                )"
            );

            foreach ($tasks as $t) {
                $logId = !empty($t['id']) ? (string)$t['id'] : $this->generateUuid();
                $taskId = $t['task_id'] ?? null;
                if (empty($taskId) && !empty($t['task_name'])) {
                    $stmtFind = $this->db->prepare("SELECT id FROM maintenance_tasks_template WHERE LOWER(task_name) LIKE LOWER(?) LIMIT 1");
                    $stmtFind->execute(['%' . trim((string)$t['task_name']) . '%']);
                    $taskId = $stmtFind->fetchColumn() ?: null;
                }
                if (empty($taskId)) {
                    $taskId = '10000000-0000-0000-0000-000000000001';
                }

                $stmtLog->execute([
                    $logId,
                    $visitId,
                    $vehicleId,
                    $taskId,
                    $contactId,
                    $b['service_date'],
                    $odometerKm,
                    (float)($t['cost_parts_usd'] ?? 0),
                    (float)($t['cost_labor_usd'] ?? 0),
                    $t['part_brand'] ?? null,
                    !empty($t['part_number']) ? trim((string)$t['part_number']) : null,
                    !empty($t['fluid_volume_l']) ? (float)$t['fluid_volume_l'] : null,
                    $t['wheel_positions'] ?? null,
                    $t['tire_dot_code'] ?? null,
                    !empty($t['measurement_mm']) ? (float)$t['measurement_mm'] : null,
                    $t['warranty_expires_date'] ?? null,
                    $t['notes'] ?? null,
                    !empty($t['next_due_km']) ? (int)$t['next_due_km'] : null,
                    $t['next_due_date'] ?? null,
                ]);
            }

            // 3. Update vehicle odometer if visit odometer is higher
            $stmtOdo = $this->db->prepare(
                "UPDATE vehicles SET current_odometer_km = ? WHERE id = ? AND current_odometer_km < ?"
            );
            $stmtOdo->execute([$odometerKm, $vehicleId, $odometerKm]);

            $this->db->commit();

            Response::success([
                'visit_id' => $visitId,
                'tasks_count' => count($tasks),
            ], 'Service bundle visit recorded successfully.', 201);

        } catch (Throwable $e) {
            $this->db->rollBack();
            error_log("createServiceVisit error: " . $e->getMessage());
            Response::error('Failed to record visit: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Create Fuel Log
     */
    public function createFuelLog(Request $request): void {
        $userId = $request->getUserId();
        $b = $request->getBody();

        if (empty($b['fill_date']) || !isset($b['odometer_km']) || empty($b['fuel_liters'])) {
            Response::error('Date, Odometer, and Liters are required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $vehicleId = $this->getValidVehicleId($userId, $b['vehicle_id'] ?? null);
            $id = !empty($b['id']) ? (string)$b['id'] : $this->generateUuid();
            $odometerKm = (int)$b['odometer_km'];
            $liters = (float)$b['fuel_liters'];
            $totalCost = (float)($b['total_cost_usd'] ?? 0);
            $pricePerLiter = (float)($b['price_per_liter_usd'] ?? ($totalCost > 0 && $liters > 0 ? $totalCost / $liters : 1.25));
            $isFull = (int)($b['is_full_tank'] ?? 1);

            // Find previous fuel log to calculate L/100km
            $stmtPrev = $this->db->prepare(
                "SELECT odometer_km FROM fuel_logs WHERE vehicle_id = ? AND odometer_km < ? AND is_deleted = 0 ORDER BY odometer_km DESC LIMIT 1"
            );
            $stmtPrev->execute([$vehicleId, $odometerKm]);
            $prevOdo = $stmtPrev->fetchColumn();

            $calculatedL100 = null;
            if ($prevOdo && $isFull) {
                $distance = $odometerKm - (int)$prevOdo;
                if ($distance > 0) {
                    $calculatedL100 = round(($liters / $distance) * 100, 2);
                }
            }

            $stmt = $this->db->prepare(
                "INSERT INTO fuel_logs (
                    id, vehicle_id, fill_date, odometer_km, fuel_liters, price_per_liter_usd,
                    total_cost_usd, is_full_tank, calculated_l_per_100km, is_deleted
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)"
            );

            $stmt->execute([
                $id,
                $vehicleId,
                $b['fill_date'],
                $odometerKm,
                $liters,
                $pricePerLiter,
                $totalCost,
                $isFull,
                $calculatedL100,
            ]);

            // Update vehicle current odometer
            $stmtOdo = $this->db->prepare("UPDATE vehicles SET current_odometer_km = ? WHERE id = ? AND current_odometer_km < ?");
            $stmtOdo->execute([$odometerKm, $vehicleId, $odometerKm]);

            Response::success([
                'id' => $id,
                'calculated_l_per_100km' => $calculatedL100,
            ], 'Fuel log added successfully.', 201);

        } catch (Throwable $e) {
            Response::error('Failed to log fuel: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Create Diagnostic Symptom
     */
    public function createSymptom(Request $request): void {
        $userId = $request->getUserId();
        $b = $request->getBody();

        if (empty($b['symptom_description'])) {
            Response::error('Symptom description is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $vehicleId = $this->getValidVehicleId($userId, $b['vehicle_id'] ?? null);
            $id = !empty($b['id']) ? (string)$b['id'] : $this->generateUuid();

            $stmt = $this->db->prepare(
                "INSERT INTO diagnostic_symptoms (
                    id, vehicle_id, logged_date, odometer_km, obd_code,
                    engine_state, symptom_description, audio_clip_url, is_resolved, is_deleted
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0)"
            );

            $stmt->execute([
                $id,
                $vehicleId,
                $b['logged_date'] ?? date('Y-m-d'),
                (int)($b['odometer_km'] ?? 0),
                !empty($b['obd_code']) ? strtoupper(trim((string)$b['obd_code'])) : null,
                $b['engine_state'] ?? 'other',
                trim((string)$b['symptom_description']),
                $b['audio_clip_url'] ?? null,
            ]);

            Response::success(['id' => $id], 'Symptom recorded.', 201);
        } catch (Throwable $e) {
            Response::error('Failed to log symptom: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Resolve Symptom
     */
    public function resolveSymptom(Request $request): void {
        $id = $request->getParam('id');

        try {
            $stmt = $this->db->prepare("UPDATE diagnostic_symptoms SET is_resolved = 1 WHERE id = ?");
            $stmt->execute([$id]);
            Response::success(['id' => $id], 'Symptom marked as resolved.');
        } catch (Throwable $e) {
            Response::error('Failed to resolve symptom: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Create / Update Inventory Item
     */
    public function createInventoryItem(Request $request): void {
        $userId = $request->getUserId();
        $b = $request->getBody();

        if (empty($b['item_name'])) {
            Response::error('Item name is required', 'VALIDATION_ERROR', 400);
            return;
        }

        $id = !empty($b['id']) ? (string)$b['id'] : $this->generateUuid();

        try {
            $stmt = $this->db->prepare(
                "INSERT INTO garage_inventory (
                    id, user_id, vehicle_id, task_id, item_name, part_brand,
                    part_number, quantity, unit_label, purchase_price_usd, is_deleted
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)"
            );

            $stmt->execute([
                $id,
                $userId,
                $b['vehicle_id'] ?? null,
                $b['task_id'] ?? null,
                trim((string)$b['item_name']),
                $b['part_brand'] ?? null,
                $b['part_number'] ?? null,
                (float)($b['quantity'] ?? 1.0),
                $b['unit_label'] ?? 'pcs',
                !empty($b['purchase_price_usd']) ? (float)$b['purchase_price_usd'] : null,
            ]);

            Response::success(['id' => $id], 'Inventory item added.', 201);
        } catch (Throwable $e) {
            Response::error('Failed to save inventory: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Adjust Inventory Quantity
     */
    public function updateInventoryQuantity(Request $request): void {
        $id = $request->getParam('id');
        $b = $request->getBody();

        try {
            if (isset($b['quantity'])) {
                $newQty = max(0.0, (float)$b['quantity']);
                $stmt = $this->db->prepare("UPDATE garage_inventory SET quantity = ? WHERE id = ?");
                $stmt->execute([$newQty, $id]);
            } else {
                $delta = (float)($b['delta'] ?? 0);
                $stmt = $this->db->prepare("UPDATE garage_inventory SET quantity = CASE WHEN quantity + ? < 0 THEN 0 ELSE quantity + ? END WHERE id = ?");
                $stmt->execute([$delta, $delta, $id]);
            }
            Response::success(['id' => $id], 'Quantity adjusted.');
        } catch (Throwable $e) {
            Response::error('Failed to adjust quantity: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Create Workshop Contact
     */
    public function createContact(Request $request): void {
        $userId = $request->getUserId();
        $b = $request->getBody();

        if (empty($b['shop_name'])) {
            Response::error('Shop name is required', 'VALIDATION_ERROR', 400);
            return;
        }

        $id = !empty($b['id']) ? (string)$b['id'] : $this->generateUuid();

        try {
            $stmt = $this->db->prepare(
                "INSERT INTO contacts_directory (id, user_id, shop_name, specialty, phone, location_notes, is_deleted)
                 VALUES (?, ?, ?, ?, ?, ?, 0)"
            );
            $stmt->execute([
                $id,
                $userId,
                trim((string)$b['shop_name']),
                $b['specialty'] ?? 'mechanic',
                $b['phone'] ?? null,
                $b['location_notes'] ?? null,
            ]);

            Response::success(['id' => $id], 'Contact added.', 201);
        } catch (Throwable $e) {
            Response::error('Failed to add contact: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Public Share Link Generator
     */
    public function generateShareToken(Request $request): void {
        $userId = $request->getUserId();
        $vehicleId = $request->getParam('id');
        $hideCosts = (int)$request->get('hide_costs', 1);

        try {
            $stmt = $this->db->prepare("SELECT id, public_share_token FROM vehicles WHERE id = ? AND user_id = ? AND is_deleted = 0 LIMIT 1");
            $stmt->execute([$vehicleId, $userId]);
            $vehicle = $stmt->fetch();

            if (!$vehicle) {
                Response::error('Vehicle not found or unauthorized', 'NOT_FOUND', 404);
                return;
            }

            $token = $vehicle['public_share_token'];
            if (empty($token)) {
                $token = bin2hex(random_bytes(24));
            }

            $update = $this->db->prepare(
                "UPDATE vehicles SET public_share_token = ?, hide_costs_on_share = ? WHERE id = ?"
            );
            $update->execute([$token, $hideCosts, $vehicleId]);

            $baseUrl = rtrim(Config::get()['app']['base_url'], '/');
            $shareUrl = "{$baseUrl}/v/{$token}";

            Response::success([
                'public_share_token' => $token,
                'share_url' => $shareUrl,
                'hide_costs_on_share' => (bool)$hideCosts,
            ], 'Share link generated successfully.');

        } catch (Throwable $e) {
            error_log("Share token generation error: " . $e->getMessage());
            Response::error('Failed to generate share link: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Create Trip Log (Feature: Trip Logging & History)
     */
    public function createTripLog(Request $request): void {
        $userId = $request->getUserId();
        $b = $request->getBody();

        if (!isset($b['distance_km'])) {
            Response::error('Distance (km) is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $vehId = $this->getValidVehicleId($userId, $b['vehicle_id'] ?? null);
            $id = !empty($b['id']) ? (string)$b['id'] : $this->generateUuid();
            $tripDate = !empty($b['trip_date']) ? (string)$b['trip_date'] : date('Y-m-d');
            $tripTime = !empty($b['trip_time']) ? (string)$b['trip_time'] : date('H:i:s');
            $distanceKm = (float)$b['distance_km'];
            $purpose = !empty($b['purpose']) ? (string)$b['purpose'] : 'Commute';
            $startOdo = !empty($b['start_odometer_km']) ? (int)$b['start_odometer_km'] : null;
            $endOdo = !empty($b['end_odometer_km']) ? (int)$b['end_odometer_km'] : null;
            $notes = !empty($b['notes']) ? (string)$b['notes'] : null;

            $stmtV = $this->db->prepare("SELECT id, current_odometer_km FROM vehicles WHERE id = ?");
            $stmtV->execute([$vehId]);
            $veh = $stmtV->fetch();

            $stmt = $this->db->prepare(
                "INSERT INTO trip_logs (id, vehicle_id, trip_date, trip_time, start_odometer_km, end_odometer_km, distance_km, purpose, notes, is_deleted)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)"
            );
            $stmt->execute([$id, $vehId, $tripDate, $tripTime, $startOdo, $endOdo, $distanceKm, $purpose, $notes]);

            // Update vehicle current odometer if end_odometer_km is provided and higher
            if ($endOdo && $endOdo > (int)$veh['current_odometer_km']) {
                $uOdo = $this->db->prepare("UPDATE vehicles SET current_odometer_km = ? WHERE id = ?");
                $uOdo->execute([$endOdo, $vehId]);
            }

            Response::success([
                'id' => $id,
                'vehicle_id' => $vehId,
                'distance_km' => $distanceKm,
                'purpose' => $purpose,
            ], 'Trip logged successfully.', 201);
        } catch (Throwable $e) {
            Response::error('Failed to save trip: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Delete Trip Log
     */
    public function deleteTripLog(Request $request): void {
        $userId = $request->getUserId();
        $id = $request->getParam('id');

        try {
            $stmt = $this->db->prepare(
                "UPDATE trip_logs SET is_deleted = 1 
                 WHERE id = ? AND vehicle_id IN (SELECT id FROM vehicles WHERE user_id = ?)"
            );
            $stmt->execute([$id, $userId]);
            Response::success(['id' => $id], 'Trip log deleted.');
        } catch (Throwable $e) {
            Response::error('Failed to delete trip: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Create General Expense (Parking, Tolls, Wash, Fines, Insurance)
     */
    public function createGeneralExpense(Request $request): void {
        $userId = $request->getUserId();
        $b = $request->getBody();

        if (!isset($b['amount_usd'])) {
            Response::error('Amount (USD) is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $vehId = $this->getValidVehicleId($userId, $b['vehicle_id'] ?? null);
            $id = !empty($b['id']) ? (string)$b['id'] : $this->generateUuid();
            $expDate = !empty($b['expense_date']) ? (string)$b['expense_date'] : date('Y-m-d');
            $expTime = !empty($b['expense_time']) ? (string)$b['expense_time'] : date('H:i:s');
            $expType = !empty($b['expense_type']) ? (string)$b['expense_type'] : 'Parking';
            $amountUsd = (float)$b['amount_usd'];
            $odometer = !empty($b['odometer_km']) ? (int)$b['odometer_km'] : null;
            $notes = !empty($b['notes']) ? (string)$b['notes'] : null;
            $receiptPhoto = !empty($b['receipt_photo_url']) ? (string)$b['receipt_photo_url'] : null;

            $stmt = $this->db->prepare(
                "INSERT INTO general_expenses (id, vehicle_id, expense_date, expense_time, expense_type, amount_usd, odometer_km, notes, receipt_photo_url, is_deleted)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)"
            );
            $stmt->execute([$id, $vehId, $expDate, $expTime, $expType, $amountUsd, $odometer, $notes, $receiptPhoto]);

            Response::success([
                'id' => $id,
                'vehicle_id' => $vehId,
                'expense_type' => $expType,
                'amount_usd' => $amountUsd,
            ], 'Expense logged successfully.', 201);
        } catch (Throwable $e) {
            Response::error('Failed to log expense: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Delete General Expense
     */
    public function deleteGeneralExpense(Request $request): void {
        $userId = $request->getUserId();
        $id = $request->getParam('id');

        try {
            $stmt = $this->db->prepare(
                "UPDATE general_expenses SET is_deleted = 1 
                 WHERE id = ? AND vehicle_id IN (SELECT id FROM vehicles WHERE user_id = ?)"
            );
            $stmt->execute([$id, $userId]);
            Response::success(['id' => $id], 'Expense deleted.');
        } catch (Throwable $e) {
            Response::error('Failed to delete expense: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Create Reminder (Upcoming & Overdue tracking)
     */
    public function createReminder(Request $request): void {
        $userId = $request->getUserId();
        $b = $request->getBody();

        if (empty($b['reminder_title'])) {
            Response::error('Reminder Title is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $vehId = $this->getValidVehicleId($userId, $b['vehicle_id'] ?? null);
            $id = !empty($b['id']) ? (string)$b['id'] : $this->generateUuid();
            $title = trim((string)$b['reminder_title']);
            $category = !empty($b['reminder_category']) ? (string)$b['reminder_category'] : 'Maintenance';
            $dueDate = !empty($b['due_date']) ? (string)$b['due_date'] : null;
            $dueKm = !empty($b['due_odometer_km']) ? (int)$b['due_odometer_km'] : null;
            $notes = !empty($b['notes']) ? (string)$b['notes'] : null;

            $stmt = $this->db->prepare(
                "INSERT INTO vehicle_reminders (id, vehicle_id, reminder_title, reminder_category, due_date, due_odometer_km, is_completed, notes, is_deleted)
                 VALUES (?, ?, ?, ?, ?, ?, 0, ?, 0)"
            );
            $stmt->execute([$id, $vehId, $title, $category, $dueDate, $dueKm, $notes]);

            Response::success([
                'id' => $id,
                'vehicle_id' => $vehId,
                'reminder_title' => $title,
                'due_date' => $dueDate,
                'due_odometer_km' => $dueKm,
            ], 'Reminder added successfully.', 201);
        } catch (Throwable $e) {
            Response::error('Failed to add reminder: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Toggle Reminder Complete / Uncomplete
     */
    public function toggleReminder(Request $request): void {
        $userId = $request->getUserId();
        $id = $request->getParam('id');

        try {
            $stmt = $this->db->prepare(
                "SELECT vr.id, vr.is_completed FROM vehicle_reminders vr
                 JOIN vehicles v ON vr.vehicle_id = v.id
                 WHERE vr.id = ? AND v.user_id = ? AND vr.is_deleted = 0 LIMIT 1"
            );
            $stmt->execute([$id, $userId]);
            $rem = $stmt->fetch();

            if (!$rem) {
                Response::error('Reminder not found or unauthorized', 'NOT_FOUND', 404);
                return;
            }

            $newStatus = (int)$rem['is_completed'] === 1 ? 0 : 1;
            $completedDate = $newStatus === 1 ? date('Y-m-d') : null;

            $u = $this->db->prepare("UPDATE vehicle_reminders SET is_completed = ?, completed_date = ? WHERE id = ?");
            $u->execute([$newStatus, $completedDate, $id]);

            Response::success([
                'id' => $id,
                'is_completed' => $newStatus,
                'completed_date' => $completedDate,
            ], $newStatus === 1 ? 'Reminder marked as completed!' : 'Reminder reopened.');
        } catch (Throwable $e) {
            Response::error('Failed to update reminder: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Delete Reminder
     */
    public function deleteReminder(Request $request): void {
        $userId = $request->getUserId();
        $id = $request->getParam('id');

        try {
            $stmt = $this->db->prepare(
                "UPDATE vehicle_reminders SET is_deleted = 1 
                 WHERE id = ? AND vehicle_id IN (SELECT id FROM vehicles WHERE user_id = ?)"
            );
            $stmt->execute([$id, $userId]);
            Response::success(['id' => $id], 'Reminder deleted.');
        } catch (Throwable $e) {
            Response::error('Failed to delete reminder: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Calculate Predictive Fluid & Wear Decay for major tasks
     */
    private function calculatePredictiveDecay(array $vehicle, array $logs): array {
        $currentOdo = (int)($vehicle['current_odometer_km'] ?? 0);
        $vehType = $vehicle['vehicle_type'] ?? 'car';

        $rules = [
            'engine_oil' => [
                'name' => 'Engine Oil & Filter',
                'category' => 'Engine & Fluids',
                'interval_km' => 10000,
                'interval_months' => 12,
                'icon' => '🛢️',
            ],
            'brake_fluid' => [
                'name' => 'Brake Fluid Flush',
                'category' => 'Brakes & Suspension',
                'interval_km' => 40000,
                'interval_months' => 24,
                'icon' => '🛑',
            ],
            'coolant' => [
                'name' => 'Coolant Flush',
                'category' => 'Cooling & HVAC',
                'interval_km' => 60000,
                'interval_months' => 36,
                'icon' => '❄️',
            ],
            'spark_plugs' => [
                'name' => 'Spark Plugs',
                'category' => 'Filters & Ignition',
                'interval_km' => 50000,
                'interval_months' => 48,
                'icon' => '⚡',
            ],
            'tires' => [
                'name' => 'Tire Rotation & Tread Life',
                'category' => 'Tires & Wheels',
                'interval_km' => 12000,
                'interval_months' => 12,
                'icon' => '🛞',
            ],
            'air_filter' => [
                'name' => 'Engine Air & Cabin Filter',
                'category' => 'Filters & Ignition',
                'interval_km' => 20000,
                'interval_months' => 12,
                'icon' => '🌬️',
            ],
        ];

        if ($vehType === 'motorcycle') {
            $rules['chain_lube'] = [
                'name' => 'Drive Chain Clean/Lube & Slack',
                'category' => 'Motorcycle Specific',
                'interval_km' => 1000,
                'interval_months' => 1,
                'icon' => '⛓️',
            ];
            $rules['chain_sprockets'] = [
                'name' => 'Chain & Sprocket Kit',
                'category' => 'Motorcycle Specific',
                'interval_km' => 25000,
                'interval_months' => 24,
                'icon' => '⚙️',
            ];
        }

        $now = time();
        $result = [];

        foreach ($rules as $key => $r) {
            // Find most recent matching maintenance log
            $lastOdo = null;
            $lastDate = null;

            foreach ($logs as $l) {
                $name = strtolower($l['task_name'] ?? '');
                if (str_contains($name, strtolower(substr($r['name'], 0, 8)))) {
                    $lastOdo = (int)$l['odometer_km'];
                    $lastDate = strtotime($l['service_date']);
                    break;
                }
            }

            // Defaults if never serviced: assume serviced at acquisition odo
            if ($lastOdo === null) {
                $lastOdo = (int)($vehicle['acquisition_odometer_km'] ?? 0);
                $lastDate = strtotime("-3 months");
            }

            $kmDriven = max(0, $currentOdo - $lastOdo);
            $kmWear = ($kmDriven / $r['interval_km']) * 100;

            $daysPassed = max(0, (int)(($now - $lastDate) / 86400));
            $daysAllowed = $r['interval_months'] * 30.4375;
            $timeWear = ($daysPassed / $daysAllowed) * 100;

            $worstWear = round(max($kmWear, $timeWear), 1);
            $kmRemaining = max(0, $r['interval_km'] - $kmDriven);
            $daysRemaining = max(0, (int)($daysAllowed - $daysPassed));

            $status = 'healthy'; // < 80%
            if ($worstWear >= 100) {
                $status = 'overdue';
            } else if ($worstWear >= 80) {
                $status = 'warning';
            }

            $result[] = [
                'key' => $key,
                'name' => $r['name'],
                'category' => $r['category'],
                'icon' => $r['icon'],
                'wear_pct' => min(100, $worstWear),
                'km_remaining' => $kmRemaining,
                'days_remaining' => $daysRemaining,
                'status' => $status,
                'interval_km' => $r['interval_km'],
                'interval_months' => $r['interval_months'],
            ];
        }

        return $result;
    }

    /**
     * Seeds initial user vehicle (clones demo vehicle)
     */
    private function seedInitialUserVehicle(string $userId): void {
        $vehId = $this->generateUuid();
        $shareToken = bin2hex(random_bytes(20));

        $stmt = $this->db->prepare(
            "INSERT INTO vehicles (
                id, user_id, vehicle_type, vin, plate_number, make, model, year,
                engine_displacement_cc, engine_code, power_kw, transmission_type,
                fuel_type, acquisition_odometer_km, current_odometer_km, photo_url,
                public_share_token, hide_costs_on_share, is_deleted
            ) VALUES (
                ?, ?, 'car', '2T1BURHE7NC123456', 'B 789123', 'TOYOTA', 'COROLLA', 2022,
                1798, '2ZR-FAE', 103, 'cvt',
                'gasoline', 0, 32450, 'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?w=800&q=80',
                ?, 1, 0
            )"
        );
        $stmt->execute([$vehId, $userId, $shareToken]);

        // Quick specs
        $stmtSpecs = $this->db->prepare(
            "INSERT INTO vehicle_quick_specs (
                vehicle_id, oil_viscosity, oil_capacity_l, coolant_spec, coolant_capacity_l,
                front_tire_size, rear_tire_size, front_tire_pressure_bar, rear_tire_pressure_bar,
                wiper_driver_mm, wiper_passenger_mm, wiper_rear_mm, battery_spec,
                spark_plug_gap_mm, wheel_lug_torque_nm
            ) VALUES (
                ?, '0W-20 Full Synthetic', 4.20, 'Toyota Pink SLLC', 6.50,
                '205/55R16 91V', '205/55R16 91V', 2.30, 2.20,
                700, 350, 300, '12V 45Ah LN1 AGM',
                1.10, 103
            )"
        );
        $stmtSpecs->execute([$vehId]);

        // Workshop contact
        $contactId = $this->generateUuid();
        $stmtContact = $this->db->prepare(
            "INSERT INTO contacts_directory (id, user_id, shop_name, specialty, phone, location_notes)
             VALUES (?, ?, 'Apex Auto Precision', 'mechanic', '+1 555-0192', 'Central Bay Industrial')"
        );
        $stmtContact->execute([$contactId, $userId]);

        // Service Visit 1
        $visitId1 = $this->generateUuid();
        $stmtV1 = $this->db->prepare(
            "INSERT INTO service_visits (id, vehicle_id, contact_id, service_date, odometer_km, visit_title, is_deleted)
             VALUES (?, ?, ?, '2024-03-15', 10120, '10,000 km Scheduled Service', 0)"
        );
        $stmtV1->execute([$visitId1, $vehId, $contactId]);

        $stmtL1 = $this->db->prepare(
            "INSERT INTO maintenance_logs (id, visit_id, vehicle_id, task_id, contact_id, service_date, odometer_km, cost_parts_usd, cost_labor_usd, part_brand, part_number, fluid_volume_l, is_deleted)
             VALUES (?, ?, ?, '10000000-0000-0000-0000-000000000001', ?, '2024-03-15', 10120, 45.00, 25.00, 'Mann-Filter', 'W 68/3', 4.20, 0)"
        );
        $stmtL1->execute([$this->generateUuid(), $visitId1, $vehId, $contactId]);

        // Service Visit 2
        $visitId2 = $this->generateUuid();
        $stmtV2 = $this->db->prepare(
            "INSERT INTO service_visits (id, vehicle_id, contact_id, service_date, odometer_km, visit_title, is_deleted)
             VALUES (?, ?, ?, '2024-09-20', 20350, '20,000 km Major Service', 0)"
        );
        $stmtV2->execute([$visitId2, $vehId, $contactId]);

        $stmtL2 = $this->db->prepare(
            "INSERT INTO maintenance_logs (id, visit_id, vehicle_id, task_id, contact_id, service_date, odometer_km, cost_parts_usd, cost_labor_usd, part_brand, part_number, fluid_volume_l, is_deleted)
             VALUES (?, ?, ?, '10000000-0000-0000-0000-000000000001', ?, '2024-09-20', 20350, 48.00, 30.00, 'Mann-Filter', 'W 68/3', 4.20, 0)"
        );
        $stmtL2->execute([$this->generateUuid(), $visitId2, $vehId, $contactId]);

        $stmtL3 = $this->db->prepare(
            "INSERT INTO maintenance_logs (id, visit_id, vehicle_id, task_id, contact_id, service_date, odometer_km, cost_parts_usd, cost_labor_usd, part_brand, part_number, is_deleted)
             VALUES (?, ?, ?, '10000000-0000-0000-0000-000000000010', ?, '2024-09-20', 20350, 28.00, 15.00, 'Denso', '17801-0T060', 0)"
        );
        $stmtL3->execute([$this->generateUuid(), $visitId2, $vehId, $contactId]);

        // Fuel logs
        $stmtFuel1 = $this->db->prepare(
            "INSERT INTO fuel_logs (id, vehicle_id, fill_date, odometer_km, fuel_liters, price_per_liter_usd, total_cost_usd, is_full_tank, calculated_l_per_100km, is_deleted)
             VALUES (?, ?, '2025-01-10', 31800, 42.50, 1.250, 53.13, 1, 6.20, 0)"
        );
        $stmtFuel1->execute([$this->generateUuid(), $vehId]);

        $stmtFuel2 = $this->db->prepare(
            "INSERT INTO fuel_logs (id, vehicle_id, fill_date, odometer_km, fuel_liters, price_per_liter_usd, total_cost_usd, is_full_tank, calculated_l_per_100km, is_deleted)
             VALUES (?, ?, '2025-01-25', 32450, 40.20, 1.280, 51.46, 1, 6.18, 0)"
        );
        $stmtFuel2->execute([$this->generateUuid(), $vehId]);

        // Demo Trip Logs
        $stmtTrip1 = $this->db->prepare(
            "INSERT INTO trip_logs (id, vehicle_id, trip_date, trip_time, start_odometer_km, end_odometer_km, distance_km, purpose, notes, is_deleted)
             VALUES (?, ?, '2026-11-15', '22:28:00', 32432, 32450, 18.00, 'Commute', 'Office return trip via ring highway', 0)"
        );
        $stmtTrip1->execute([$this->generateUuid(), $vehId]);

        $stmtTrip2 = $this->db->prepare(
            "INSERT INTO trip_logs (id, vehicle_id, trip_date, trip_time, start_odometer_km, end_odometer_km, distance_km, purpose, notes, is_deleted)
             VALUES (?, ?, '2026-11-12', '18:15:00', 32410, 32432, 22.00, 'Personal', 'City center groceries & weekend errands', 0)"
        );
        $stmtTrip2->execute([$this->generateUuid(), $vehId]);

        // Demo General Expense
        $stmtExp = $this->db->prepare(
            "INSERT INTO general_expenses (id, vehicle_id, expense_date, expense_time, expense_type, amount_usd, odometer_km, notes, is_deleted)
             VALUES (?, ?, '2026-11-13', '22:28:00', 'Parking', 12.00, 32432, 'City center underground garage 4 hrs', 0)"
        );
        $stmtExp->execute([$this->generateUuid(), $vehId]);

        // Demo Reminders
        $demoReminders = [
            ['Tire pressure check', 'Tires', '2026-11-18', null],
            ['Registration renewal', 'Registration', '2026-11-30', null],
            ['Tire Rotation', 'Tires', '2026-12-06', 35450],
            ['General Service', 'Maintenance', '2026-12-31', 36450],
            ['Brake inspection', 'Inspection', '2026-11-09', null],
            ['Insurance renewal', 'Insurance', '2026-11-13', null],
        ];
        $stmtRem = $this->db->prepare(
            "INSERT INTO vehicle_reminders (id, vehicle_id, reminder_title, reminder_category, due_date, due_odometer_km, is_completed, is_deleted)
             VALUES (?, ?, ?, ?, ?, ?, 0, 0)"
        );
        foreach ($demoReminders as $dr) {
            $stmtRem->execute([$this->generateUuid(), $vehId, $dr[0], $dr[1], $dr[2], $dr[3]]);
        }
    }
}
