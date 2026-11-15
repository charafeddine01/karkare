<?php
declare(strict_types=1);

// CarLog - Public QR Code Digital Service Book Web View
// URL: /v/{public_share_token}

if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
    require_once __DIR__ . '/../vendor/autoload.php';
}

spl_autoload_register(function (string $class) {
    $prefix = 'CarLog\\';
    $baseDir = __DIR__ . '/../src/';
    $configDir = __DIR__ . '/../config/';
    if (!str_starts_with($class, $prefix)) return;
    $relativeClass = substr($class, strlen($prefix));
    $file = str_starts_with($relativeClass, 'Config\\')
        ? $configDir . str_replace('\\', '/', substr($relativeClass, 7)) . '.php'
        : $baseDir . str_replace('\\', '/', $relativeClass) . '.php';
    if (file_exists($file)) require_once $file;
});

use CarLog\Config\Database;

$token = $_GET['token'] ?? '';
$token = preg_replace('/[^a-zA-Z0-9_\-]/', '', (string)$token);

if (empty($token)) {
    http_response_code(404);
    echo "<h1>404 - Service Record Not Found</h1>";
    exit;
}

try {
    $db = Database::getConnection();

    // 1. Fetch Vehicle
    $stmt = $db->prepare("SELECT * FROM vehicles WHERE public_share_token = ? AND is_deleted = 0 LIMIT 1");
    $stmt->execute([$token]);
    $vehicle = $stmt->fetch();

    if (!$vehicle) {
        http_response_code(404);
        include __DIR__ . '/not_found.html';
        exit;
    }

    // 2. Fetch Quick Specs
    $stmtSpecs = $db->prepare("SELECT * FROM vehicle_quick_specs WHERE vehicle_id = ? LIMIT 1");
    $stmtSpecs->execute([$vehicle['id']]);
    $specs = $stmtSpecs->fetch();

    // 3. Fetch Service Visits & Logs
    $stmtLogs = $db->prepare(
        "SELECT ml.*, t.task_name, t.category, sv.visit_title, sv.notes AS visit_notes, c.shop_name, c.specialty 
         FROM maintenance_logs ml
         JOIN maintenance_tasks_template t ON ml.task_id = t.id
         LEFT JOIN service_visits sv ON ml.visit_id = sv.id
         LEFT JOIN contacts_directory c ON ml.contact_id = c.id
         WHERE ml.vehicle_id = ? AND ml.is_deleted = 0
         ORDER BY ml.service_date DESC, ml.odometer_km DESC"
    );
    $stmtLogs->execute([$vehicle['id']]);
    $logs = $stmtLogs->fetchAll();

} catch (Throwable $e) {
    http_response_code(500);
    echo "<h1>Service Unavailable</h1><p>" . htmlspecialchars($e->getMessage()) . "</p>";
    exit;
}

$hideCosts = (bool)$vehicle['hide_costs_on_share'];
$pageTitle = htmlspecialchars("{$vehicle['year']} {$vehicle['make']} {$vehicle['model']} - Verified Service Book");
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= $pageTitle ?></title>
    <style>
        :root {
            --bg-dark: #0b1120;
            --surface: #1e293b;
            --surface-hover: #334155;
            --border: #334155;
            --primary: #38bdf8;
            --primary-glow: rgba(56, 189, 248, 0.2);
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --accent-green: #22c55e;
            --accent-amber: #f59e0b;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
            background-color: var(--bg-dark);
            color: var(--text-main);
            padding: 24px 16px;
            line-height: 1.5;
        }
        .container { max-width: 900px; margin: 0 auto; }
        .header {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 24px;
            box-shadow: 0 10px 25px rgba(0,0,0,0.4);
            flex-wrap: wrap;
            gap: 16px;
        }
        .header-title h1 { font-size: 24px; font-weight: 800; color: #fff; }
        .header-title p { color: var(--text-muted); font-size: 14px; margin-top: 4px; }
        .badge-verified {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: rgba(34, 197, 94, 0.15);
            color: var(--accent-green);
            border: 1px solid var(--accent-green);
            padding: 6px 14px;
            border-radius: 9999px;
            font-size: 13px;
            font-weight: 700;
            letter-spacing: 0.5px;
        }
        .grid-stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 16px;
            margin-bottom: 24px;
        }
        .stat-card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 16px;
        }
        .stat-card .label { font-size: 12px; text-transform: uppercase; color: var(--text-muted); font-weight: 600; }
        .stat-card .val { font-size: 20px; font-weight: 700; color: var(--primary); margin-top: 4px; }

        .specs-panel {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 20px;
            margin-bottom: 28px;
        }
        .specs-panel h3 { font-size: 16px; color: #fff; margin-bottom: 14px; display: flex; align-items: center; gap: 8px; }
        .specs-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 12px;
            font-size: 13px;
        }
        .spec-item { display: flex; justify-content: space-between; border-bottom: 1px dashed #334155; padding-bottom: 6px; }
        .spec-item span:first-child { color: var(--text-muted); }
        .spec-item span:last-child { font-weight: 600; color: #fff; }

        .section-title {
            font-size: 20px;
            font-weight: 800;
            margin-bottom: 16px;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .timeline { position: relative; padding-left: 24px; }
        .timeline::before {
            content: '';
            position: absolute;
            top: 8px;
            bottom: 0;
            left: 7px;
            width: 2px;
            background: #334155;
        }
        .timeline-item {
            position: relative;
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 20px;
            margin-bottom: 20px;
            transition: border-color 0.2s;
        }
        .timeline-item:hover { border-color: var(--primary); }
        .timeline-dot {
            position: absolute;
            left: -23px;
            top: 24px;
            width: 14px;
            height: 14px;
            border-radius: 50%;
            background: var(--primary);
            box-shadow: 0 0 10px var(--primary);
            border: 3px solid var(--bg-dark);
        }
        .item-head {
            display: flex;
            justify-content: space-between;
            align-items: flex-start;
            flex-wrap: wrap;
            gap: 8px;
            margin-bottom: 12px;
        }
        .task-name { font-size: 17px; font-weight: 700; color: #fff; }
        .category-pill {
            font-size: 11px;
            text-transform: uppercase;
            background: rgba(56, 189, 248, 0.12);
            color: var(--primary);
            padding: 3px 8px;
            border-radius: 6px;
            font-weight: 700;
        }
        .meta-line {
            display: flex;
            gap: 16px;
            font-size: 13px;
            color: var(--text-muted);
            margin-bottom: 12px;
            flex-wrap: wrap;
        }
        .meta-line strong { color: #f1f5f9; }
        .part-box {
            background: #0f172a;
            border-radius: 8px;
            padding: 12px;
            margin-top: 10px;
            font-size: 13px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
            gap: 8px;
        }
        .notes-box {
            margin-top: 10px;
            font-size: 13px;
            color: #cbd5e1;
            font-style: italic;
            background: rgba(15, 23, 42, 0.6);
            padding: 8px 12px;
            border-radius: 6px;
        }
        .footer {
            text-align: center;
            font-size: 12px;
            color: var(--text-muted);
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid var(--border);
        }
    </style>
</head>
<body>
    <div class="container">
        <!-- Header -->
        <div class="header">
            <div class="header-title">
                <span style="font-size: 11px; font-weight: 800; letter-spacing: 1px; color: var(--primary);">CARLOG DIGITAL SERVICE BOOK</span>
                <h1><?= htmlspecialchars($vehicle['year'] . ' ' . $vehicle['make'] . ' ' . $vehicle['model']) ?></h1>
                <p>Type: <strong><?= strtoupper(htmlspecialchars($vehicle['vehicle_type'])) ?></strong> &bull; Plate: <strong><?= htmlspecialchars($vehicle['plate_number'] ?: 'N/A') ?></strong> &bull; VIN: <strong><?= htmlspecialchars($vehicle['vin'] ?: 'N/A') ?></strong></p>
            </div>
            <div class="badge-verified">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
                VERIFIED MAINTENANCE LOG
            </div>
        </div>

        <!-- Vehicle Core Stats -->
        <div class="grid-stats">
            <div class="stat-card">
                <div class="label">Current Odometer</div>
                <div class="val"><?= number_format((float)$vehicle['current_odometer_km']) ?> km</div>
            </div>
            <div class="stat-card">
                <div class="label">Engine & Displacement</div>
                <div class="val"><?= (int)$vehicle['engine_displacement_cc'] > 0 ? htmlspecialchars((string)$vehicle['engine_displacement_cc']) . ' cc' : 'N/A' ?></div>
            </div>
            <div class="stat-card">
                <div class="label">Power & Transmission</div>
                <div class="val"><?= (int)$vehicle['power_kw'] > 0 ? htmlspecialchars((string)$vehicle['power_kw']) . ' kW' : 'N/A' ?> &bull; <?= ucfirst(htmlspecialchars((string)$vehicle['transmission_type'])) ?></div>
            </div>
            <div class="stat-card">
                <div class="label">Fuel Type</div>
                <div class="val"><?= ucfirst(htmlspecialchars($vehicle['fuel_type'])) ?></div>
            </div>
        </div>

        <!-- Quick Specs Reference -->
        <?php if ($specs): ?>
        <div class="specs-panel">
            <h3>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
                Glovebox Quick-Specs Reference (100% Metric)
            </h3>
            <div class="specs-grid">
                <?php if (!empty($specs['oil_viscosity']) || !empty($specs['oil_capacity_l'])): ?>
                    <div class="spec-item">
                        <span>Engine Oil:</span>
                        <span><?= htmlspecialchars(($specs['oil_viscosity'] ?? '') . ' (' . ($specs['oil_capacity_l'] ? $specs['oil_capacity_l'] . ' L' : 'N/A') . ')') ?></span>
                    </div>
                <?php endif; ?>
                <?php if (!empty($specs['coolant_spec']) || !empty($specs['coolant_capacity_l'])): ?>
                    <div class="spec-item">
                        <span>Coolant:</span>
                        <span><?= htmlspecialchars(($specs['coolant_spec'] ?? '') . ' (' . ($specs['coolant_capacity_l'] ? $specs['coolant_capacity_l'] . ' L' : 'N/A') . ')') ?></span>
                    </div>
                <?php endif; ?>
                <?php if (!empty($specs['front_tire_pressure_bar']) || !empty($specs['rear_tire_pressure_bar'])): ?>
                    <div class="spec-item">
                        <span>Tire Pressure:</span>
                        <span>Front <?= htmlspecialchars((string)($specs['front_tire_pressure_bar'] ?? '-')) ?> Bar &bull; Rear <?= htmlspecialchars((string)($specs['rear_tire_pressure_bar'] ?? '-')) ?> Bar</span>
                    </div>
                <?php endif; ?>
                <?php if (!empty($specs['wheel_lug_torque_nm'])): ?>
                    <div class="spec-item">
                        <span>Wheel Lug Torque:</span>
                        <span><?= htmlspecialchars((string)$specs['wheel_lug_torque_nm']) ?> Nm</span>
                    </div>
                <?php endif; ?>
                <?php if (!empty($specs['spark_plug_gap_mm'])): ?>
                    <div class="spec-item">
                        <span>Spark Plug Gap:</span>
                        <span><?= htmlspecialchars((string)$specs['spark_plug_gap_mm']) ?> mm</span>
                    </div>
                <?php endif; ?>
                <?php if (!empty($specs['chain_pitch_mm'])): ?>
                    <div class="spec-item">
                        <span>Motorcycle Chain Pitch:</span>
                        <span><?= htmlspecialchars($specs['chain_pitch_mm']) ?></span>
                    </div>
                <?php endif; ?>
            </div>
        </div>
        <?php endif; ?>

        <!-- Service History Timeline -->
        <div class="section-title">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
            Complete Chronological Service History (<?= count($logs) ?> Records)
        </div>

        <?php if (empty($logs)): ?>
            <div style="background: var(--surface); padding: 32px; border-radius: 12px; text-align: center; color: var(--text-muted);">
                No maintenance records currently logged for this vehicle.
            </div>
        <?php else: ?>
            <div class="timeline">
                <?php foreach ($logs as $log): ?>
                    <div class="timeline-item">
                        <div class="timeline-dot"></div>
                        <div class="item-head">
                            <div>
                                <span class="category-pill"><?= htmlspecialchars($log['category']) ?></span>
                                <div class="task-name"><?= htmlspecialchars($log['task_name']) ?></div>
                            </div>
                            <?php if (!$hideCosts): ?>
                                <div style="text-align: right; color: var(--accent-green); font-weight: 700; font-size: 16px;">
                                    $<?= number_format((float)$log['total_cost_usd'], 2) ?> USD
                                </div>
                            <?php endif; ?>
                        </div>

                        <div class="meta-line">
                            <div>Date: <strong><?= htmlspecialchars(date('M d, Y', strtotime($log['service_date']))) ?></strong></div>
                            <div>Odometer: <strong><?= number_format((float)$log['odometer_km']) ?> km</strong></div>
                            <?php if (!empty($log['shop_name'])): ?>
                                <div>Workshop: <strong><?= htmlspecialchars($log['shop_name']) ?></strong></div>
                            <?php endif; ?>
                            <?php if (!empty($log['visit_title'])): ?>
                                <div>Visit: <strong><?= htmlspecialchars($log['visit_title']) ?></strong></div>
                            <?php endif; ?>
                        </div>

                        <?php if (!empty($log['part_number']) || !empty($log['part_brand']) || !empty($log['fluid_volume_l']) || !empty($log['wheel_positions'])): ?>
                            <div class="part-box">
                                <?php if (!empty($log['part_brand'])): ?>
                                    <div>Brand: <strong style="color:#fff;"><?= htmlspecialchars($log['part_brand']) ?></strong></div>
                                <?php endif; ?>
                                <?php if (!empty($log['part_number'])): ?>
                                    <div>Part #: <strong style="color: var(--primary); font-family: monospace;"><?= htmlspecialchars($log['part_number']) ?></strong></div>
                                <?php endif; ?>
                                <?php if (!empty($log['fluid_volume_l'])): ?>
                                    <div>Fluid Vol: <strong style="color:#fff;"><?= htmlspecialchars($log['fluid_volume_l']) ?> L</strong></div>
                                <?php endif; ?>
                                <?php if (!empty($log['wheel_positions'])): ?>
                                    <div>Position: <strong style="color:#fff;"><?= htmlspecialchars($log['wheel_positions']) ?></strong></div>
                                <?php endif; ?>
                                <?php if (!empty($log['tire_dot_code'])): ?>
                                    <div>Tire DOT: <strong style="color:#fff;"><?= htmlspecialchars($log['tire_dot_code']) ?></strong></div>
                                <?php endif; ?>
                                <?php if (!empty($log['measurement_mm'])): ?>
                                    <div>Measured: <strong style="color:#fff;"><?= htmlspecialchars($log['measurement_mm']) ?> mm</strong></div>
                                <?php endif; ?>
                                <?php if (!empty($log['warranty_expires_date'])): ?>
                                    <div>Warranty Until: <strong style="color:#fff;"><?= htmlspecialchars(date('M Y', strtotime($log['warranty_expires_date']))) ?></strong></div>
                                <?php endif; ?>
                            </div>
                        <?php endif; ?>

                        <?php if (!empty($log['notes'])): ?>
                            <div class="notes-box">&ldquo;<?= htmlspecialchars($log['notes']) ?>&rdquo;</div>
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>

        <div class="footer">
            Powered by <strong>CarLog</strong> &bull; The Offline-First Vehicle & Motorcycle Maintenance Platform &bull; Metric (km, L, Bar) &bull; USD ($)
        </div>
    </div>
</body>
</html>
