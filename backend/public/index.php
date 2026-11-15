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

// Health check
$router->get('/api/health', function (Request $req) {
    Response::success([
        'status' => 'healthy',
        'service' => 'CarLog API',
        'version' => '1.0.0',
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

// Vehicles (Protected)
$router->post('/api/vehicles/{id}/share-token', [VehicleController::class, 'generateShareToken'], [$authMiddleware]);

// 4. Dispatch Request
$request = new Request();
$router->dispatch($request);
