<?php
declare(strict_types=1);

// CarLog API Front Controller
// Environment: Shared Hosting / LiteSpeed / Apache PHP 8.2+

// 1. PSR-4 Autoloader & Composer Autoload
if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
    require_once __DIR__ . '/../vendor/autoload.php';
}

spl_autoload_register(function (string $class) {
    $prefix = 'CarLog\\';
    $baseDir = __DIR__ . '/../src/';
    $configDir = __DIR__ . '/../config/';

    if (!str_starts_with($class, $prefix)) {
        return;
    }

    $relativeClass = substr($class, strlen($prefix));
    
    if (str_starts_with($relativeClass, 'Config\\')) {
        $file = $configDir . str_replace('\\', '/', substr($relativeClass, 7)) . '.php';
    } else {
        $file = $baseDir . str_replace('\\', '/', $relativeClass) . '.php';
    }

    if (file_exists($file)) {
        require_once $file;
    }
});

use CarLog\Router\Request;
use CarLog\Router\Response;
use CarLog\Router\Router;
use CarLog\Middleware\AuthMiddleware;
use CarLog\Controllers\AuthController;
use CarLog\Controllers\SyncController;
use CarLog\Controllers\UploadController;
use CarLog\Controllers\PartCatalogController;
use CarLog\Controllers\VehicleController;

// 2. Global Error Handling
set_exception_handler(function (Throwable $e) {
    error_log("Unhandled exception: " . $e->getMessage() . "\n" . $e->getTraceAsString());
    Response::error($e->getMessage(), 'UNHANDLED_EXCEPTION', 500);
});

set_error_handler(function (int $errno, string $errstr, string $errfile, int $errline) {
    if (!(error_reporting() & $errno)) {
        return false;
    }
    error_log("PHP Error [{$errno}]: {$errstr} in {$errfile} on line {$errline}");
    return true;
});

// 3. Initialize Router & Routes
$router = new Router();
$authMiddleware = [AuthMiddleware::class, 'handle'];

// Root Platform Status & Portal
$router->get('/', function (Request $req) {
    $accept = $_SERVER['HTTP_ACCEPT'] ?? '';
    if (str_contains($accept, 'text/html')) {
        header('Content-Type: text/html; charset=UTF-8');
        echo '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CarLog — Vehicle Maintenance Platform</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;600;700;800&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-primary: #0B0F19;
            --bg-card: #151D2E;
            --brand-primary: #2563EB;
            --brand-accent: #38BDF8;
            --success: #10B981;
            --text-primary: #F8FAFC;
            --text-secondary: #94A3B8;
            --border: rgba(255, 255, 255, 0.08);
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            background: var(--bg-primary);
            color: var(--text-primary);
            font-family: \'Plus Jakarta Sans\', sans-serif;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
        }
        .card {
            background: var(--bg-card);
            border: 1px solid var(--border);
            border-radius: 20px;
            max-width: 640px;
            width: 100%;
            padding: 40px;
            box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5);
            text-align: center;
        }
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            background: rgba(16, 185, 129, 0.12);
            color: var(--success);
            border: 1px solid rgba(16, 185, 129, 0.3);
            padding: 6px 14px;
            border-radius: 9999px;
            font-size: 13px;
            font-weight: 700;
            margin-bottom: 24px;
        }
        .pulse-dot {
            width: 8px;
            height: 8px;
            background: var(--success);
            border-radius: 50%;
            box-shadow: 0 0 10px var(--success);
        }
        h1 {
            font-size: 32px;
            font-weight: 800;
            margin-bottom: 12px;
            letter-spacing: -0.5px;
        }
        p.lead {
            color: var(--text-secondary);
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 32px;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
            gap: 16px;
            margin-bottom: 32px;
            text-align: left;
        }
        .grid-item {
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 16px;
        }
        .grid-item .title {
            font-size: 12px;
            color: var(--text-secondary);
            text-transform: uppercase;
            font-weight: 700;
            letter-spacing: 0.5px;
        }
        .grid-item .val {
            font-size: 15px;
            font-weight: 700;
            color: #fff;
            margin-top: 4px;
        }
        .actions {
            display: flex;
            gap: 12px;
            justify-content: center;
            flex-wrap: wrap;
        }
        .btn {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 12px 24px;
            border-radius: 12px;
            font-weight: 700;
            font-size: 14px;
            text-decoration: none;
            transition: all 0.2s;
        }
        .btn-primary {
            background: var(--brand-primary);
            color: #fff;
        }
        .btn-primary:hover {
            background: #1d4ed8;
            transform: translateY(-1px);
        }
        .btn-secondary {
            background: rgba(255, 255, 255, 0.06);
            color: #fff;
            border: 1px solid var(--border);
        }
        .btn-secondary:hover {
            background: rgba(255, 255, 255, 0.1);
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="badge">
            <span class="pulse-dot"></span>
            API & Service Engine Operational
        </div>
        <h1>CarLog Platform</h1>
        <p class="lead">Offline-First Vehicle & Motorcycle Maintenance Platform with MariaDB Delta Sync, ML Kit OCR, and Verified Digital Service Books.</p>
        <div class="grid">
            <div class="grid-item">
                <div class="title">Currency</div>
                <div class="val">USD ($) Strictly</div>
            </div>
            <div class="grid-item">
                <div class="title">Measurement</div>
                <div class="val">100% Metric (km, L, Bar)</div>
            </div>
            <div class="grid-item">
                <div class="title">Sync Engine</div>
                <div class="val">Bidirectional Delta</div>
            </div>
        </div>
        <div class="actions">
            <a href="login" class="btn btn-primary">
                <span>Launch Garage (Sign In)</span> &rarr;
            </a>
            <a href="v/demo-corolla-2022" class="btn btn-secondary">
                <span>Service Book Demo</span>
            </a>
            <a href="api/health" class="btn btn-secondary">
                <span>API Health Status</span>
            </a>
        </div>
    </div>
</body>
</html>';
        exit;
    }

    Response::success([
        'platform' => 'CarLog Vehicle Maintenance Platform',
        'status' => 'operational',
        'version' => '1.0.0',
        'demo_book_url' => '/v/demo-corolla-2022',
        'health_url' => '/api/health',
        'units' => '100% Metric (km, L, Bar, mm, kW, Nm)',
        'currency' => 'USD ($)',
    ]);
});

// Health check
$router->get('/api/health', function (Request $req) {
    // Ensure DB connection is initialized
    try {
        \CarLog\Config\Database::getConnection();
        $dbStatus = 'connected (' . \CarLog\Config\Database::getDriver() . ')';
        $note = \CarLog\Config\Database::getLastError();
    } catch (\Throwable $e) {
        $dbStatus = 'error: ' . $e->getMessage();
        $note = null;
    }

    Response::success([
        'status' => 'healthy',
        'service' => 'CarLog API',
        'version' => '1.0.0',
        'database' => $dbStatus,
        'mysql_note' => $note,
        'timestamp' => date('c'),
    ]);
});

// Auth Routes (Public)
$router->post('/api/auth/register', [AuthController::class, 'register']);
$router->post('/api/auth/verify-email', [AuthController::class, 'verifyEmail']);
$router->post('/api/auth/resend-code', [AuthController::class, 'resendCode']);
$router->post('/api/auth/login', [AuthController::class, 'login']);
$router->post('/api/auth/google', [AuthController::class, 'googleSignIn']);
$router->post('/api/auth/refresh', [AuthController::class, 'refresh']);

// Auth Routes (Protected)
$router->get('/api/auth/me', [AuthController::class, 'me'], [$authMiddleware]);

// Sync Delta Engine (Protected)
$router->post('/api/sync/push', [SyncController::class, 'push'], [$authMiddleware]);
$router->get('/api/sync/pull', [SyncController::class, 'pull'], [$authMiddleware]);

// Media Upload (Protected)
$router->post('/api/upload', [UploadController::class, 'upload'], [$authMiddleware]);

// Part Catalog & Suggestions (Protected)
$router->get('/api/parts/suggest', [PartCatalogController::class, 'suggest'], [$authMiddleware]);
$router->get('/api/obd/lookup', [PartCatalogController::class, 'searchObd']);

// Vehicles & Garage (Protected)
$router->get('/api/garage', [VehicleController::class, 'getGarage'], [$authMiddleware]);
$router->post('/api/vehicles', [VehicleController::class, 'createVehicle'], [$authMiddleware]);
$router->post('/api/vehicles/{id}', [VehicleController::class, 'updateVehicle'], [$authMiddleware]);
$router->post('/api/vehicles/{id}/specs', [VehicleController::class, 'saveQuickSpecs'], [$authMiddleware]);
$router->post('/api/vehicles/{id}/share-token', [VehicleController::class, 'generateShareToken'], [$authMiddleware]);

// Service Bundles (Protected)
$router->post('/api/service-visits', [VehicleController::class, 'createServiceVisit'], [$authMiddleware]);

// Fuel Analytics (Protected)
$router->post('/api/fuel-logs', [VehicleController::class, 'createFuelLog'], [$authMiddleware]);

// Diagnostic Symptoms (Protected)
$router->post('/api/symptoms', [VehicleController::class, 'createSymptom'], [$authMiddleware]);
$router->post('/api/symptoms/{id}/resolve', [VehicleController::class, 'resolveSymptom'], [$authMiddleware]);

// Inventory & Contacts (Protected)
$router->post('/api/inventory', [VehicleController::class, 'createInventoryItem'], [$authMiddleware]);
$router->post('/api/inventory/{id}/quantity', [VehicleController::class, 'updateInventoryQuantity'], [$authMiddleware]);
$router->post('/api/contacts', [VehicleController::class, 'createContact'], [$authMiddleware]);

// Public QR Digital Service Book & Verification (Feature L)
$router->get('/v/{token}', function (Request $req) {
    $_GET['token'] = $req->getParam('token');
    require __DIR__ . '/view.php';
});

$router->get('/api/verify/{token}', function (Request $req) {
    $token = preg_replace('/[^a-zA-Z0-9_\-]/', '', (string)$req->getParam('token'));
    if (empty($token)) {
        Response::error('Invalid verification token', 'VALIDATION_ERROR', 400);
        return;
    }
    try {
        $db = \CarLog\Config\Database::getConnection();
        $stmt = $db->prepare("SELECT * FROM vehicles WHERE public_share_token = ? AND is_deleted = 0 LIMIT 1");
        $stmt->execute([$token]);
        $vehicle = $stmt->fetch();
        if (!$vehicle) {
            Response::error('Vehicle service book not found or private', 'NOT_FOUND', 404);
            return;
        }

        // Fetch specs
        $stmtSpecs = $db->prepare("SELECT * FROM vehicle_quick_specs WHERE vehicle_id = ?");
        $stmtSpecs->execute([$vehicle['id']]);
        $specs = $stmtSpecs->fetch() ?: null;

        // Fetch visits
        $stmtVisits = $db->prepare(
            "SELECT sv.id, sv.service_date, sv.odometer_km, sv.visit_title, sv.receipt_photo_url, sv.notes,
                    cd.shop_name
             FROM service_visits sv
             LEFT JOIN contacts_directory cd ON sv.contact_id = cd.id
             WHERE sv.vehicle_id = ? AND sv.is_deleted = 0
             ORDER BY sv.service_date DESC, sv.odometer_km DESC"
        );
        $stmtVisits->execute([$vehicle['id']]);
        $visits = $stmtVisits->fetchAll();

        // Fetch logs
        $stmtLogs = $db->prepare(
            "SELECT ml.*, mtt.task_name, mtt.category as task_category
             FROM maintenance_logs ml
             LEFT JOIN maintenance_tasks_template mtt ON ml.task_id = mtt.id
             WHERE ml.vehicle_id = ? AND ml.is_deleted = 0
             ORDER BY ml.id ASC"
        );
        $stmtLogs->execute([$vehicle['id']]);
        $allLogs = $stmtLogs->fetchAll();

        $logsByVisit = [];
        foreach ($allLogs as $l) {
            $vid = $l['visit_id'] ?? 'unassigned';
            $logsByVisit[$vid][] = $l;
        }

        foreach ($visits as &$v) {
            $v['tasks'] = $logsByVisit[$v['id']] ?? [];
        }

        Response::success([
            'vehicle' => [
                'make' => $vehicle['make'],
                'model' => $vehicle['model'],
                'year' => (int)$vehicle['year'],
                'vehicle_type' => $vehicle['vehicle_type'],
                'vin' => $vehicle['vin'],
                'current_odometer_km' => (int)$vehicle['current_odometer_km'],
                'photo_url' => $vehicle['photo_url'] ?? null,
                'public_share_token' => $vehicle['public_share_token'],
            ],
            'quick_specs' => $specs,
            'visits' => $visits,
            'is_verified' => true,
        ], 'Verified digital service record retrieved.');
    } catch (\Throwable $e) {
        Response::error('Verification failed: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
    }
});

// 4. Dispatch Request
$request = new Request();
$router->dispatch($request);
