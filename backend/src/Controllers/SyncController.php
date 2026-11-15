<?php
declare(strict_types=1);

namespace CarLog\Controllers;

use CarLog\Config\Database;
use CarLog\Router\Request;
use CarLog\Router\Response;
use PDO;
use Throwable;

class SyncController {
    private PDO $db;
    private string $driver;

    public function __construct() {
        $this->db = Database::getConnection();
        $this->driver = Database::getDriver();
    }

    private function prepareUpsert(string $mysqlSql, string $sqliteSql): \PDOStatement {
        return $this->db->prepare($this->driver === 'sqlite' ? $sqliteSql : $mysqlSql);
    }

    /**
     * Push client offline changes to MariaDB/SQLite server
     */
    public function push(Request $request): void {
        $userId = $request->getUserId();
        $payload = $request->getBody();

        if (empty($payload) || !is_array($payload)) {
            Response::error('Invalid sync push payload', 'INVALID_PAYLOAD', 400);
            return;
        }

        $syncedIds = [
            'vehicles' => [],
            'vehicle_quick_specs' => [],
            'contacts_directory' => [],
            'maintenance_tasks_template' => [],
            'service_visits' => [],
            'maintenance_logs' => [],
            'diagnostic_symptoms' => [],
            'fuel_logs' => [],
            'garage_inventory' => [],
        ];

        $this->db->beginTransaction();

        try {
            // 1. Vehicles
            if (!empty($payload['vehicles']) && is_array($payload['vehicles'])) {
                $upsertVehicle = $this->prepareUpsert(
                    "INSERT INTO vehicles (
                        id, user_id, vehicle_type, vin, plate_number, make, model, year,
                        engine_displacement_cc, engine_code, power_kw, transmission_type,
                        fuel_type, acquisition_odometer_km, current_odometer_km, photo_url,
                        public_share_token, hide_costs_on_share, is_deleted, updated_at
                    ) VALUES (
                        :id, :user_id, :vehicle_type, :vin, :plate_number, :make, :model, :year,
                        :engine_displacement_cc, :engine_code, :power_kw, :transmission_type,
                        :fuel_type, :acquisition_odometer_km, :current_odometer_km, :photo_url,
                        :public_share_token, :hide_costs_on_share, :is_deleted, CURRENT_TIMESTAMP(3)
                    ) ON DUPLICATE KEY UPDATE
                        vehicle_type = VALUES(vehicle_type),
                        vin = VALUES(vin),
                        plate_number = VALUES(plate_number),
                        make = VALUES(make),
                        model = VALUES(model),
                        year = VALUES(year),
                        engine_displacement_cc = VALUES(engine_displacement_cc),
                        engine_code = VALUES(engine_code),
                        power_kw = VALUES(power_kw),
                        transmission_type = VALUES(transmission_type),
                        fuel_type = VALUES(fuel_type),
                        acquisition_odometer_km = VALUES(acquisition_odometer_km),
                        current_odometer_km = VALUES(current_odometer_km),
                        photo_url = VALUES(photo_url),
                        public_share_token = VALUES(public_share_token),
                        hide_costs_on_share = VALUES(hide_costs_on_share),
                        is_deleted = VALUES(is_deleted),
                        updated_at = CURRENT_TIMESTAMP(3)",
                    "INSERT OR REPLACE INTO vehicles (
                        id, user_id, vehicle_type, vin, plate_number, make, model, year,
                        engine_displacement_cc, engine_code, power_kw, transmission_type,
                        fuel_type, acquisition_odometer_km, current_odometer_km, photo_url,
                        public_share_token, hide_costs_on_share, is_deleted, updated_at
                    ) VALUES (
                        :id, :user_id, :vehicle_type, :vin, :plate_number, :make, :model, :year,
                        :engine_displacement_cc, :engine_code, :power_kw, :transmission_type,
                        :fuel_type, :acquisition_odometer_km, :current_odometer_km, :photo_url,
                        :public_share_token, :hide_costs_on_share, :is_deleted, CURRENT_TIMESTAMP
                    )"
                );

                foreach ($payload['vehicles'] as $v) {
                    $isDeleted = ($v['is_deleted'] ?? 0) || (($v['sync_status'] ?? '') === 'pending_delete') ? 1 : 0;
                    $upsertVehicle->execute([
                        ':id' => $v['id'],
                        ':user_id' => $userId,
                        ':vehicle_type' => $v['vehicle_type'] ?? 'car',
                        ':vin' => $v['vin'] ?? null,
                        ':plate_number' => $v['plate_number'] ?? null,
                        ':make' => $v['make'],
                        ':model' => $v['model'],
                        ':year' => (int)$v['year'],
                        ':engine_displacement_cc' => !empty($v['engine_displacement_cc']) ? (int)$v['engine_displacement_cc'] : null,
                        ':engine_code' => $v['engine_code'] ?? null,
                        ':power_kw' => !empty($v['power_kw']) ? (int)$v['power_kw'] : null,
                        ':transmission_type' => $v['transmission_type'] ?? 'manual',
                        ':fuel_type' => $v['fuel_type'] ?? 'gasoline',
                        ':acquisition_odometer_km' => (int)($v['acquisition_odometer_km'] ?? 0),
                        ':current_odometer_km' => (int)($v['current_odometer_km'] ?? 0),
                        ':photo_url' => $v['photo_url'] ?? null,
                        ':public_share_token' => $v['public_share_token'] ?? null,
                        ':hide_costs_on_share' => (int)($v['hide_costs_on_share'] ?? 1),
                        ':is_deleted' => $isDeleted,
                    ]);
                    $syncedIds['vehicles'][] = $v['id'];
                }
            }

            // 2. Vehicle Quick Specs
            if (!empty($payload['vehicle_quick_specs']) && is_array($payload['vehicle_quick_specs'])) {
                $upsertSpecs = $this->prepareUpsert(
                    "INSERT INTO vehicle_quick_specs (
                        vehicle_id, oil_viscosity, oil_capacity_l, coolant_spec, coolant_capacity_l,
                        front_tire_size, rear_tire_size, front_tire_pressure_bar, rear_tire_pressure_bar,
                        wiper_driver_mm, wiper_passenger_mm, wiper_rear_mm, battery_spec,
                        spark_plug_gap_mm, wheel_lug_torque_nm, chain_pitch_mm, updated_at
                    ) VALUES (
                        :vehicle_id, :oil_viscosity, :oil_capacity_l, :coolant_spec, :coolant_capacity_l,
                        :front_tire_size, :rear_tire_size, :front_tire_pressure_bar, :rear_tire_pressure_bar,
                        :wiper_driver_mm, :wiper_passenger_mm, :wiper_rear_mm, :battery_spec,
                        :spark_plug_gap_mm, :wheel_lug_torque_nm, :chain_pitch_mm, CURRENT_TIMESTAMP(3)
                    ) ON DUPLICATE KEY UPDATE
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
                        updated_at = CURRENT_TIMESTAMP(3)",
                    "INSERT OR REPLACE INTO vehicle_quick_specs (
                        vehicle_id, oil_viscosity, oil_capacity_l, coolant_spec, coolant_capacity_l,
                        front_tire_size, rear_tire_size, front_tire_pressure_bar, rear_tire_pressure_bar,
                        wiper_driver_mm, wiper_passenger_mm, wiper_rear_mm, battery_spec,
                        spark_plug_gap_mm, wheel_lug_torque_nm, chain_pitch_mm, updated_at
                    ) VALUES (
                        :vehicle_id, :oil_viscosity, :oil_capacity_l, :coolant_spec, :coolant_capacity_l,
                        :front_tire_size, :rear_tire_size, :front_tire_pressure_bar, :rear_tire_pressure_bar,
                        :wiper_driver_mm, :wiper_passenger_mm, :wiper_rear_mm, :battery_spec,
                        :spark_plug_gap_mm, :wheel_lug_torque_nm, :chain_pitch_mm, CURRENT_TIMESTAMP
                    )"
                );

                foreach ($payload['vehicle_quick_specs'] as $s) {
                    $upsertSpecs->execute([
                        ':vehicle_id' => $s['vehicle_id'],
                        ':oil_viscosity' => $s['oil_viscosity'] ?? null,
                        ':oil_capacity_l' => $s['oil_capacity_l'] ?? null,
                        ':coolant_spec' => $s['coolant_spec'] ?? null,
                        ':coolant_capacity_l' => $s['coolant_capacity_l'] ?? null,
                        ':front_tire_size' => $s['front_tire_size'] ?? null,
                        ':rear_tire_size' => $s['rear_tire_size'] ?? null,
                        ':front_tire_pressure_bar' => $s['front_tire_pressure_bar'] ?? null,
                        ':rear_tire_pressure_bar' => $s['rear_tire_pressure_bar'] ?? null,
                        ':wiper_driver_mm' => $s['wiper_driver_mm'] ?? null,
                        ':wiper_passenger_mm' => $s['wiper_passenger_mm'] ?? null,
                        ':wiper_rear_mm' => $s['wiper_rear_mm'] ?? null,
                        ':battery_spec' => $s['battery_spec'] ?? null,
                        ':spark_plug_gap_mm' => $s['spark_plug_gap_mm'] ?? null,
                        ':wheel_lug_torque_nm' => $s['wheel_lug_torque_nm'] ?? null,
                        ':chain_pitch_mm' => $s['chain_pitch_mm'] ?? null,
                    ]);
                    $syncedIds['vehicle_quick_specs'][] = $s['vehicle_id'];
                }
            }

            // 3. Contacts Directory
            if (!empty($payload['contacts_directory']) && is_array($payload['contacts_directory'])) {
                $upsertContact = $this->prepareUpsert(
                    "INSERT INTO contacts_directory (
                        id, user_id, shop_name, specialty, phone, location_notes, is_deleted, updated_at
                    ) VALUES (
                        :id, :user_id, :shop_name, :specialty, :phone, :location_notes, :is_deleted, CURRENT_TIMESTAMP(3)
                    ) ON DUPLICATE KEY UPDATE
                        shop_name = VALUES(shop_name),
                        specialty = VALUES(specialty),
                        phone = VALUES(phone),
                        location_notes = VALUES(location_notes),
                        is_deleted = VALUES(is_deleted),
                        updated_at = CURRENT_TIMESTAMP(3)",
                    "INSERT OR REPLACE INTO contacts_directory (
                        id, user_id, shop_name, specialty, phone, location_notes, is_deleted, updated_at
                    ) VALUES (
                        :id, :user_id, :shop_name, :specialty, :phone, :location_notes, :is_deleted, CURRENT_TIMESTAMP
                    )"
                );

                foreach ($payload['contacts_directory'] as $c) {
                    $isDeleted = ($c['is_deleted'] ?? 0) || (($c['sync_status'] ?? '') === 'pending_delete') ? 1 : 0;
                    $upsertContact->execute([
                        ':id' => $c['id'],
                        ':user_id' => $userId,
                        ':shop_name' => $c['shop_name'],
                        ':specialty' => $c['specialty'] ?? 'mechanic',
                        ':phone' => $c['phone'] ?? null,
                        ':location_notes' => $c['location_notes'] ?? null,
                        ':is_deleted' => $isDeleted,
                    ]);
                    $syncedIds['contacts_directory'][] = $c['id'];
                }
            }

            // 4. Custom Maintenance Tasks Template
            if (!empty($payload['maintenance_tasks_template']) && is_array($payload['maintenance_tasks_template'])) {
                $upsertTask = $this->prepareUpsert(
                    "INSERT INTO maintenance_tasks_template (
                        id, user_id, category, task_name, applicable_to, default_interval_km,
                        default_interval_months, is_deleted, updated_at
                    ) VALUES (
                        :id, :user_id, :category, :task_name, :applicable_to, :default_interval_km,
                        :default_interval_months, :is_deleted, CURRENT_TIMESTAMP(3)
                    ) ON DUPLICATE KEY UPDATE
                        category = VALUES(category),
                        task_name = VALUES(task_name),
                        applicable_to = VALUES(applicable_to),
                        default_interval_km = VALUES(default_interval_km),
                        default_interval_months = VALUES(default_interval_months),
                        is_deleted = VALUES(is_deleted),
                        updated_at = CURRENT_TIMESTAMP(3)",
                    "INSERT OR REPLACE INTO maintenance_tasks_template (
                        id, user_id, category, task_name, applicable_to, default_interval_km,
                        default_interval_months, is_deleted, updated_at
                    ) VALUES (
                        :id, :user_id, :category, :task_name, :applicable_to, :default_interval_km,
                        :default_interval_months, :is_deleted, CURRENT_TIMESTAMP
                    )"
                );

                foreach ($payload['maintenance_tasks_template'] as $t) {
                    $isDeleted = ($t['is_deleted'] ?? 0) || (($t['sync_status'] ?? '') === 'pending_delete') ? 1 : 0;
                    $upsertTask->execute([
                        ':id' => $t['id'],
                        ':user_id' => $userId,
                        ':category' => $t['category'],
                        ':task_name' => $t['task_name'],
                        ':applicable_to' => $t['applicable_to'] ?? 'all',
                        ':default_interval_km' => $t['default_interval_km'] ?? null,
                        ':default_interval_months' => $t['default_interval_months'] ?? null,
                        ':is_deleted' => $isDeleted,
                    ]);
                    $syncedIds['maintenance_tasks_template'][] = $t['id'];
                }
            }

            // 5. Service Visits
            if (!empty($payload['service_visits']) && is_array($payload['service_visits'])) {
                $upsertVisit = $this->prepareUpsert(
                    "INSERT INTO service_visits (
                        id, vehicle_id, contact_id, service_date, odometer_km,
                        visit_title, receipt_photo_url, notes, is_deleted, updated_at
                    ) VALUES (
                        :id, :vehicle_id, :contact_id, :service_date, :odometer_km,
                        :visit_title, :receipt_photo_url, :notes, :is_deleted, CURRENT_TIMESTAMP(3)
                    ) ON DUPLICATE KEY UPDATE
                        contact_id = VALUES(contact_id),
                        service_date = VALUES(service_date),
                        odometer_km = VALUES(odometer_km),
                        visit_title = VALUES(visit_title),
                        receipt_photo_url = VALUES(receipt_photo_url),
                        notes = VALUES(notes),
                        is_deleted = VALUES(is_deleted),
                        updated_at = CURRENT_TIMESTAMP(3)",
                    "INSERT OR REPLACE INTO service_visits (
                        id, vehicle_id, contact_id, service_date, odometer_km,
                        visit_title, receipt_photo_url, notes, is_deleted, updated_at
                    ) VALUES (
                        :id, :vehicle_id, :contact_id, :service_date, :odometer_km,
                        :visit_title, :receipt_photo_url, :notes, :is_deleted, CURRENT_TIMESTAMP
                    )"
                );

                foreach ($payload['service_visits'] as $v) {
                    $isDeleted = ($v['is_deleted'] ?? 0) || (($v['sync_status'] ?? '') === 'pending_delete') ? 1 : 0;
                    $upsertVisit->execute([
                        ':id' => $v['id'],
                        ':vehicle_id' => $v['vehicle_id'],
                        ':contact_id' => $v['contact_id'] ?? null,
                        ':service_date' => $v['service_date'],
                        ':odometer_km' => (int)$v['odometer_km'],
                        ':visit_title' => $v['visit_title'] ?? null,
                        ':receipt_photo_url' => $v['receipt_photo_url'] ?? null,
                        ':notes' => $v['notes'] ?? null,
                        ':is_deleted' => $isDeleted,
                    ]);
                    $syncedIds['service_visits'][] = $v['id'];
                }
            }

            // 6. Maintenance Logs
            if (!empty($payload['maintenance_logs']) && is_array($payload['maintenance_logs'])) {
                $upsertLog = $this->prepareUpsert(
                    "INSERT INTO maintenance_logs (
                        id, visit_id, vehicle_id, task_id, contact_id, service_date,
                        odometer_km, cost_parts_usd, cost_labor_usd, part_brand,
                        part_number, fluid_volume_l, wheel_positions, tire_dot_code,
                        measurement_mm, warranty_expires_date, notes, receipt_photo_url,
                        next_due_km, next_due_date, is_deleted, updated_at
                    ) VALUES (
                        :id, :visit_id, :vehicle_id, :task_id, :contact_id, :service_date,
                        :odometer_km, :cost_parts_usd, :cost_labor_usd, :part_brand,
                        :part_number, :fluid_volume_l, :wheel_positions, :tire_dot_code,
                        :measurement_mm, :warranty_expires_date, :notes, :receipt_photo_url,
                        :next_due_km, :next_due_date, :is_deleted, CURRENT_TIMESTAMP(3)
                    ) ON DUPLICATE KEY UPDATE
                        visit_id = VALUES(visit_id),
                        task_id = VALUES(task_id),
                        contact_id = VALUES(contact_id),
                        service_date = VALUES(service_date),
                        odometer_km = VALUES(odometer_km),
                        cost_parts_usd = VALUES(cost_parts_usd),
                        cost_labor_usd = VALUES(cost_labor_usd),
                        part_brand = VALUES(part_brand),
                        part_number = VALUES(part_number),
                        fluid_volume_l = VALUES(fluid_volume_l),
                        wheel_positions = VALUES(wheel_positions),
                        tire_dot_code = VALUES(tire_dot_code),
                        measurement_mm = VALUES(measurement_mm),
                        warranty_expires_date = VALUES(warranty_expires_date),
                        notes = VALUES(notes),
                        receipt_photo_url = VALUES(receipt_photo_url),
                        next_due_km = VALUES(next_due_km),
                        next_due_date = VALUES(next_due_date),
                        is_deleted = VALUES(is_deleted),
                        updated_at = CURRENT_TIMESTAMP(3)",
                    "INSERT OR REPLACE INTO maintenance_logs (
                        id, visit_id, vehicle_id, task_id, contact_id, service_date,
                        odometer_km, cost_parts_usd, cost_labor_usd, part_brand,
                        part_number, fluid_volume_l, wheel_positions, tire_dot_code,
                        measurement_mm, warranty_expires_date, notes, receipt_photo_url,
                        next_due_km, next_due_date, is_deleted, updated_at
                    ) VALUES (
                        :id, :visit_id, :vehicle_id, :task_id, :contact_id, :service_date,
                        :odometer_km, :cost_parts_usd, :cost_labor_usd, :part_brand,
                        :part_number, :fluid_volume_l, :wheel_positions, :tire_dot_code,
                        :measurement_mm, :warranty_expires_date, :notes, :receipt_photo_url,
                        :next_due_km, :next_due_date, :is_deleted, CURRENT_TIMESTAMP
                    )"
                );

                foreach ($payload['maintenance_logs'] as $l) {
                    $isDeleted = ($l['is_deleted'] ?? 0) || (($l['sync_status'] ?? '') === 'pending_delete') ? 1 : 0;
                    $upsertLog->execute([
                        ':id' => $l['id'],
                        ':visit_id' => $l['visit_id'] ?? null,
                        ':vehicle_id' => $l['vehicle_id'],
                        ':task_id' => $l['task_id'],
                        ':contact_id' => $l['contact_id'] ?? null,
                        ':service_date' => $l['service_date'],
                        ':odometer_km' => (int)$l['odometer_km'],
                        ':cost_parts_usd' => (float)($l['cost_parts_usd'] ?? 0.0),
                        ':cost_labor_usd' => (float)($l['cost_labor_usd'] ?? 0.0),
                        ':part_brand' => $l['part_brand'] ?? null,
                        ':part_number' => $l['part_number'] ?? null,
                        ':fluid_volume_l' => $l['fluid_volume_l'] ?? null,
                        ':wheel_positions' => $l['wheel_positions'] ?? null,
                        ':tire_dot_code' => $l['tire_dot_code'] ?? null,
                        ':measurement_mm' => $l['measurement_mm'] ?? null,
                        ':warranty_expires_date' => $l['warranty_expires_date'] ?? null,
                        ':notes' => $l['notes'] ?? null,
                        ':receipt_photo_url' => $l['receipt_photo_url'] ?? null,
                        ':next_due_km' => $l['next_due_km'] ?? null,
                        ':next_due_date' => $l['next_due_date'] ?? null,
                        ':is_deleted' => $isDeleted,
                    ]);
                    $syncedIds['maintenance_logs'][] = $l['id'];
                }
            }

            // 7. Diagnostic Symptoms
            if (!empty($payload['diagnostic_symptoms']) && is_array($payload['diagnostic_symptoms'])) {
                $upsertSymptom = $this->prepareUpsert(
                    "INSERT INTO diagnostic_symptoms (
                        id, vehicle_id, resolved_by_log_id, logged_date, odometer_km,
                        obd_code, engine_state, symptom_description, audio_clip_url,
                        is_resolved, is_deleted, updated_at
                    ) VALUES (
                        :id, :vehicle_id, :resolved_by_log_id, :logged_date, :odometer_km,
                        :obd_code, :engine_state, :symptom_description, :audio_clip_url,
                        :is_resolved, :is_deleted, CURRENT_TIMESTAMP(3)
                    ) ON DUPLICATE KEY UPDATE
                        resolved_by_log_id = VALUES(resolved_by_log_id),
                        logged_date = VALUES(logged_date),
                        odometer_km = VALUES(odometer_km),
                        obd_code = VALUES(obd_code),
                        engine_state = VALUES(engine_state),
                        symptom_description = VALUES(symptom_description),
                        audio_clip_url = VALUES(audio_clip_url),
                        is_resolved = VALUES(is_resolved),
                        is_deleted = VALUES(is_deleted),
                        updated_at = CURRENT_TIMESTAMP(3)",
                    "INSERT OR REPLACE INTO diagnostic_symptoms (
                        id, vehicle_id, resolved_by_log_id, logged_date, odometer_km,
                        obd_code, engine_state, symptom_description, audio_clip_url,
                        is_resolved, is_deleted, updated_at
                    ) VALUES (
                        :id, :vehicle_id, :resolved_by_log_id, :logged_date, :odometer_km,
                        :obd_code, :engine_state, :symptom_description, :audio_clip_url,
                        :is_resolved, :is_deleted, CURRENT_TIMESTAMP
                    )"
                );

                foreach ($payload['diagnostic_symptoms'] as $s) {
                    $isDeleted = ($s['is_deleted'] ?? 0) || (($s['sync_status'] ?? '') === 'pending_delete') ? 1 : 0;
                    $upsertSymptom->execute([
                        ':id' => $s['id'],
                        ':vehicle_id' => $s['vehicle_id'],
                        ':resolved_by_log_id' => $s['resolved_by_log_id'] ?? null,
                        ':logged_date' => $s['logged_date'],
                        ':odometer_km' => (int)$s['odometer_km'],
                        ':obd_code' => $s['obd_code'] ?? null,
                        ':engine_state' => $s['engine_state'] ?? 'other',
                        ':symptom_description' => $s['symptom_description'],
                        ':audio_clip_url' => $s['audio_clip_url'] ?? null,
                        ':is_resolved' => (int)($s['is_resolved'] ?? 0),
                        ':is_deleted' => $isDeleted,
                    ]);
                    $syncedIds['diagnostic_symptoms'][] = $s['id'];
                }
            }

            // 8. Fuel Logs
            if (!empty($payload['fuel_logs']) && is_array($payload['fuel_logs'])) {
                $upsertFuel = $this->prepareUpsert(
                    "INSERT INTO fuel_logs (
                        id, vehicle_id, fill_date, odometer_km, fuel_liters,
                        price_per_liter_usd, total_cost_usd, is_full_tank,
                        calculated_l_per_100km, is_deleted, updated_at
                    ) VALUES (
                        :id, :vehicle_id, :fill_date, :odometer_km, :fuel_liters,
                        :price_per_liter_usd, :total_cost_usd, :is_full_tank,
                        :calculated_l_per_100km, :is_deleted, CURRENT_TIMESTAMP(3)
                    ) ON DUPLICATE KEY UPDATE
                        fill_date = VALUES(fill_date),
                        odometer_km = VALUES(odometer_km),
                        fuel_liters = VALUES(fuel_liters),
                        price_per_liter_usd = VALUES(price_per_liter_usd),
                        total_cost_usd = VALUES(total_cost_usd),
                        is_full_tank = VALUES(is_full_tank),
                        calculated_l_per_100km = VALUES(calculated_l_per_100km),
                        is_deleted = VALUES(is_deleted),
                        updated_at = CURRENT_TIMESTAMP(3)",
                    "INSERT OR REPLACE INTO fuel_logs (
                        id, vehicle_id, fill_date, odometer_km, fuel_liters,
                        price_per_liter_usd, total_cost_usd, is_full_tank,
                        calculated_l_per_100km, is_deleted, updated_at
                    ) VALUES (
                        :id, :vehicle_id, :fill_date, :odometer_km, :fuel_liters,
                        :price_per_liter_usd, :total_cost_usd, :is_full_tank,
                        :calculated_l_per_100km, :is_deleted, CURRENT_TIMESTAMP
                    )"
                );

                foreach ($payload['fuel_logs'] as $f) {
                    $isDeleted = ($f['is_deleted'] ?? 0) || (($f['sync_status'] ?? '') === 'pending_delete') ? 1 : 0;
                    $upsertFuel->execute([
                        ':id' => $f['id'],
                        ':vehicle_id' => $f['vehicle_id'],
                        ':fill_date' => $f['fill_date'],
                        ':odometer_km' => (int)$f['odometer_km'],
                        ':fuel_liters' => (float)$f['fuel_liters'],
                        ':price_per_liter_usd' => (float)$f['price_per_liter_usd'],
                        ':total_cost_usd' => (float)$f['total_cost_usd'],
                        ':is_full_tank' => (int)($f['is_full_tank'] ?? 1),
                        ':calculated_l_per_100km' => $f['calculated_l_per_100km'] ?? null,
                        ':is_deleted' => $isDeleted,
                    ]);
                    $syncedIds['fuel_logs'][] = $f['id'];
                }
            }

            // 9. Garage Inventory
            if (!empty($payload['garage_inventory']) && is_array($payload['garage_inventory'])) {
                $upsertInv = $this->prepareUpsert(
                    "INSERT INTO garage_inventory (
                        id, user_id, vehicle_id, task_id, item_name, part_brand,
                        part_number, quantity, unit_label, purchase_price_usd,
                        is_deleted, updated_at
                    ) VALUES (
                        :id, :user_id, :vehicle_id, :task_id, :item_name, :part_brand,
                        :part_number, :quantity, :unit_label, :purchase_price_usd,
                        :is_deleted, CURRENT_TIMESTAMP(3)
                    ) ON DUPLICATE KEY UPDATE
                        vehicle_id = VALUES(vehicle_id),
                        task_id = VALUES(task_id),
                        item_name = VALUES(item_name),
                        part_brand = VALUES(part_brand),
                        part_number = VALUES(part_number),
                        quantity = VALUES(quantity),
                        unit_label = VALUES(unit_label),
                        purchase_price_usd = VALUES(purchase_price_usd),
                        is_deleted = VALUES(is_deleted),
                        updated_at = CURRENT_TIMESTAMP(3)",
                    "INSERT OR REPLACE INTO garage_inventory (
                        id, user_id, vehicle_id, task_id, item_name, part_brand,
                        part_number, quantity, unit_label, purchase_price_usd,
                        is_deleted, updated_at
                    ) VALUES (
                        :id, :user_id, :vehicle_id, :task_id, :item_name, :part_brand,
                        :part_number, :quantity, :unit_label, :purchase_price_usd,
                        :is_deleted, CURRENT_TIMESTAMP
                    )"
                );

                foreach ($payload['garage_inventory'] as $i) {
                    $isDeleted = ($i['is_deleted'] ?? 0) || (($i['sync_status'] ?? '') === 'pending_delete') ? 1 : 0;
                    $upsertInv->execute([
                        ':id' => $i['id'],
                        ':user_id' => $userId,
                        ':vehicle_id' => $i['vehicle_id'] ?? null,
                        ':task_id' => $i['task_id'] ?? null,
                        ':item_name' => $i['item_name'],
                        ':part_brand' => $i['part_brand'] ?? null,
                        ':part_number' => $i['part_number'] ?? null,
                        ':quantity' => (float)$i['quantity'],
                        ':unit_label' => $i['unit_label'] ?? 'pcs',
                        ':purchase_price_usd' => !empty($i['purchase_price_usd']) ? (float)$i['purchase_price_usd'] : null,
                        ':is_deleted' => $isDeleted,
                    ]);
                    $syncedIds['garage_inventory'][] = $i['id'];
                }
            }

            $this->db->commit();

            Response::success([
                'synced_ids' => $syncedIds,
                'server_timestamp' => date('Y-m-d H:i:s.v'),
            ], 'Sync push processed successfully.');

        } catch (Throwable $e) {
            $this->db->rollBack();
            error_log("Sync push failed: " . $e->getMessage() . "\n" . $e->getTraceAsString());
            Response::error('Sync push failed: ' . $e->getMessage(), 'SYNC_FAILED', 500);
        }
    }

    /**
     * Pull updates from server since last_sync_timestamp
     */
    public function pull(Request $request): void {
        $userId = $request->getUserId();
        $since = $request->getQuery('since');

        $whereClause = "";
        $params = [':user_id' => $userId];

        if (!empty($since)) {
            $whereClause = "AND updated_at > :since";
            $params[':since'] = $since;
        }

        try {
            // 1. Vehicles
            $stmt = $this->db->prepare("SELECT * FROM vehicles WHERE user_id = :user_id {$whereClause} ORDER BY updated_at ASC");
            $stmt->execute($params);
            $vehicles = $stmt->fetchAll();

            // 2. Quick Specs (for vehicles of user)
            $stmt = $this->db->prepare(
                "SELECT s.* FROM vehicle_quick_specs s 
                 INNER JOIN vehicles v ON s.vehicle_id = v.id 
                 WHERE v.user_id = :user_id {$whereClause} ORDER BY s.updated_at ASC"
            );
            $stmt->execute($params);
            $quickSpecs = $stmt->fetchAll();

            // 3. Contacts
            $stmt = $this->db->prepare("SELECT * FROM contacts_directory WHERE user_id = :user_id {$whereClause} ORDER BY updated_at ASC");
            $stmt->execute($params);
            $contacts = $stmt->fetchAll();

            // 4. Tasks Templates (System + User's custom)
            $taskParams = [':user_id' => $userId];
            $taskWhere = "(user_id IS NULL OR user_id = :user_id)";
            if (!empty($since)) {
                $taskWhere .= " AND updated_at > :since";
                $taskParams[':since'] = $since;
            }
            $stmt = $this->db->prepare("SELECT * FROM maintenance_tasks_template WHERE {$taskWhere} ORDER BY updated_at ASC");
            $stmt->execute($taskParams);
            $tasks = $stmt->fetchAll();

            // 5. Service Visits
            $stmt = $this->db->prepare(
                "SELECT sv.* FROM service_visits sv 
                 INNER JOIN vehicles v ON sv.vehicle_id = v.id 
                 WHERE v.user_id = :user_id {$whereClause} ORDER BY sv.updated_at ASC"
            );
            $stmt->execute($params);
            $visits = $stmt->fetchAll();

            // 6. Maintenance Logs
            $stmt = $this->db->prepare(
                "SELECT ml.* FROM maintenance_logs ml 
                 INNER JOIN vehicles v ON ml.vehicle_id = v.id 
                 WHERE v.user_id = :user_id {$whereClause} ORDER BY ml.updated_at ASC"
            );
            $stmt->execute($params);
            $logs = $stmt->fetchAll();

            // 7. Diagnostic Symptoms
            $stmt = $this->db->prepare(
                "SELECT ds.* FROM diagnostic_symptoms ds 
                 INNER JOIN vehicles v ON ds.vehicle_id = v.id 
                 WHERE v.user_id = :user_id {$whereClause} ORDER BY ds.updated_at ASC"
            );
            $stmt->execute($params);
            $symptoms = $stmt->fetchAll();

            // 8. Fuel Logs
            $stmt = $this->db->prepare(
                "SELECT fl.* FROM fuel_logs fl 
                 INNER JOIN vehicles v ON fl.vehicle_id = v.id 
                 WHERE v.user_id = :user_id {$whereClause} ORDER BY fl.updated_at ASC"
            );
            $stmt->execute($params);
            $fuelLogs = $stmt->fetchAll();

            // 9. Garage Inventory
            $stmt = $this->db->prepare("SELECT * FROM garage_inventory WHERE user_id = :user_id {$whereClause} ORDER BY updated_at ASC");
            $stmt->execute($params);
            $inventory = $stmt->fetchAll();

            Response::success([
                'delta' => [
                    'vehicles' => $vehicles,
                    'vehicle_quick_specs' => $quickSpecs,
                    'contacts_directory' => $contacts,
                    'maintenance_tasks_template' => $tasks,
                    'service_visits' => $visits,
                    'maintenance_logs' => $logs,
                    'diagnostic_symptoms' => $symptoms,
                    'fuel_logs' => $fuelLogs,
                    'garage_inventory' => $inventory,
                ],
                'server_timestamp' => date('Y-m-d H:i:s.v'),
            ], 'Pull sync completed successfully.');

        } catch (Throwable $e) {
            error_log("Pull sync failed: " . $e->getMessage());
            Response::error('Pull sync failed: ' . $e->getMessage(), 'SYNC_FAILED', 500);
        }
    }
}
