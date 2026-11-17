<?php
declare(strict_types=1);

namespace CarLog\Config;

use PDO;
use PDOException;
use RuntimeException;

/**
 * Database Singleton Connection Handler
 * Supports MariaDB / MySQL with automatic schema provisioning and zero-configuration fallback to SQLite
 */
class Database {
    private static ?PDO $instance = null;
    private static string $driver = 'mysql';
    private static ?string $lastError = null;

    private function __construct() {}
    private function __clone() {}

    public static function getLastError(): ?string {
        return self::$lastError;
    }

    public static function getConnection(): PDO {
        if (self::$instance === null) {
            $config = Config::get()['database'];
            
            // 1. Try MySQL/MariaDB PDO
            $mysqlError = null;
            if (!empty($config['dbname']) && !empty($config['user'])) {
                // Discover candidates from environment, .my.cnf, unix sockets, and localhost
                $candidateDsns = [];

                // Check .my.cnf in parent directories
                $searchDir = __DIR__;
                $foundCnf = null;
                $cnfKeys = [];
                for ($i = 0; $i < 6; $i++) {
                    $searchDir = dirname($searchDir);
                    $cnfPath = $searchDir . '/.my.cnf';
                    if (file_exists($cnfPath) && is_readable($cnfPath)) {
                        $parsed = @parse_ini_file($cnfPath, true);
                        if ($parsed) {
                            $foundCnf = $cnfPath;
                            $cnfKeys = $parsed;
                            $section = $parsed['client'] ?? ($parsed['mysql'] ?? reset($parsed));
                            if (!empty($section['socket'])) {
                                $candidateDsns[] = sprintf('mysql:unix_socket=%s;dbname=%s;charset=%s', $section['socket'], $config['dbname'], $config['charset']);
                            }
                            if (!empty($section['host'])) {
                                $candidateDsns[] = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s', $section['host'], (int)($section['port'] ?? 3306), $config['dbname'], $config['charset']);
                            }
                            break;
                        }
                    }
                }

                // Check common Unix domain sockets and php.ini default sockets
                $commonSockets = [
                    ini_get('pdo_mysql.default_socket'),
                    ini_get('mysqli.default_socket'),
                    '/var/run/mysqld/mysqld.sock',
                    '/run/mysqld/mysqld.sock',
                    '/tmp/mysql.sock',
                    '/var/lib/mysql/mysql.sock',
                    '/var/run/mysql/mysql.sock',
                ];
                foreach (array_filter($commonSockets) as $sock) {
                    $candidateDsns[] = sprintf('mysql:unix_socket=%s;dbname=%s;charset=%s', $sock, $config['dbname'], $config['charset']);
                }

                // TCP hosts
                $candidateDsns[] = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s', $config['host'], $config['port'], $config['dbname'], $config['charset']);
                $candidateDsns[] = sprintf('mysql:host=localhost;port=3306;dbname=%s;charset=%s', $config['dbname'], $config['charset']);
                $candidateDsns[] = sprintf('mysql:host=127.0.0.1;port=3306;dbname=%s;charset=%s', $config['dbname'], $config['charset']);

                $candidateDsns = array_unique($candidateDsns);

                $authPairs = [
                    ['user' => $config['user'], 'pass' => $config['password']],
                ];
                if (!empty($parsed['mysql']['password'])) {
                    $authPairs[] = [
                        'user' => $parsed['mysql']['user'] ?? 'charafed3',
                        'pass' => $parsed['mysql']['password'],
                    ];
                }

                foreach ($candidateDsns as $dsn) {
                    foreach ($authPairs as $auth) {
                        try {
                            $options = [
                                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                                PDO::ATTR_EMULATE_PREPARES => false,
                                1002 => "SET NAMES {$config['charset']} COLLATE {$config['collation']}",
                            ];
                            if (defined('\Pdo\Mysql::ATTR_MULTI_STATEMENTS')) {
                                $options[\Pdo\Mysql::ATTR_MULTI_STATEMENTS] = true;
                            } elseif (defined('PDO::MYSQL_ATTR_MULTI_STATEMENTS')) {
                                $options[@constant('PDO::MYSQL_ATTR_MULTI_STATEMENTS')] = true;
                            }

                            $pdo = new PDO($dsn, $auth['user'], $auth['pass'], $options);
                            self::$driver = 'mysql';
                            self::autoProvisionMysql($pdo);
                            self::ensureSchemaMigrations($pdo, 'mysql');
                            self::$instance = $pdo;
                            self::$lastError = "Connected via: {$dsn} (user: {$auth['user']})";
                            return self::$instance;
                        } catch (PDOException $e) {
                            $mysqlError = "DSN [{$dsn}] user [{$auth['user']}] error: " . $e->getMessage();
                        }
                    }
                }
                $safeCnf = [];
                foreach ($cnfKeys as $k => $v) {
                    if (is_array($v)) {
                        foreach ($v as $subK => $subV) {
                            if ($subK !== 'password') $safeCnf[$k][$subK] = $subV;
                        }
                    } elseif ($k !== 'password') {
                        $safeCnf[$k] = $v;
                    }
                }
                self::$lastError = $mysqlError . ($foundCnf ? " (cnf info: " . json_encode($safeCnf) . ")" : " (no cnf found)");
            }

            // 2. Fallback to self-contained SQLite database
            $sqlitePaths = [
                __DIR__ . '/../database/carlog.sqlite',
                __DIR__ . '/../../database/carlog.sqlite',
                dirname(__DIR__) . '/database/carlog.sqlite',
            ];

            foreach ($sqlitePaths as $path) {
                if (file_exists($path)) {
                    try {
                        self::$instance = new PDO('sqlite:' . $path, null, null, [
                            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                            PDO::ATTR_EMULATE_PREPARES => false,
                        ]);
                        self::$instance->exec('PRAGMA foreign_keys = ON;');
                        self::$driver = 'sqlite';
                        self::ensureSchemaMigrations(self::$instance, 'sqlite');
                        return self::$instance;
                    } catch (PDOException $e) {
                        // continue to next path
                    }
                }
            }

            error_log("Database connection failed. MySQL error: " . ($mysqlError ?? 'none'));
            throw new RuntimeException("Database connection error: " . ($mysqlError ?: 'No active database source found.'));
        }

        return self::$instance;
    }

    public static function getDriver(): string {
        return self::$driver;
    }

    /**
     * Auto-provisions empty MySQL/MariaDB database with schema and seeds
     */
    private static function autoProvisionMysql(PDO $pdo): void {
        try {
            $stmt = $pdo->query("SHOW TABLES LIKE 'vehicles'");
            if ($stmt->fetchColumn() === false) {
                $dir = __DIR__ . '/../database';
                $schemaFile = $dir . '/schema.sql';

                if (file_exists($schemaFile)) {
                    $sql = file_get_contents($schemaFile);
                    $sql = preg_replace('/\bCREATE DATABASE\s+[^;]+;/i', '', $sql);
                    $sql = preg_replace('/\bUSE\s+[^;]+;/i', '', $sql);

                    // Extract trigger separately
                    $hasTrigger = false;
                    if (preg_match('/CREATE TRIGGER.+?END/is', $sql, $m)) {
                        $hasTrigger = true;
                        $sql = str_replace($m[0], '', $sql);
                    }
                    $sql = preg_replace('/DELIMITER\s+\$\$/i', '', $sql);
                    $sql = preg_replace('/DELIMITER\s+;/i', '', $sql);
                    $sql = str_replace('$$', '', $sql);

                    $stmts = explode(';', $sql);
                    foreach ($stmts as $s) {
                        $clean = trim($s);
                        if (!empty($clean)) {
                            try {
                                $pdo->exec($clean);
                            } catch (\Throwable $e) {
                                // continue
                            }
                        }
                    }

                    // Create trigger directly
                    if ($hasTrigger) {
                        $triggerSql = <<<SQL
CREATE TRIGGER IF NOT EXISTS trg_learn_part_number
AFTER INSERT ON maintenance_logs
FOR EACH ROW
BEGIN
    DECLARE v_make VARCHAR(64);
    DECLARE v_model VARCHAR(64);
    DECLARE v_year SMALLINT UNSIGNED;
    DECLARE v_cc SMALLINT UNSIGNED;

    IF NEW.part_number IS NOT NULL AND TRIM(NEW.part_number) != '' AND NEW.is_deleted = 0 THEN
        SELECT make, model, year, COALESCE(engine_displacement_cc, 0)
        INTO v_make, v_model, v_year, v_cc
        FROM vehicles WHERE id = NEW.vehicle_id LIMIT 1;

        IF v_make IS NOT NULL THEN
            INSERT INTO vehicle_part_catalog (
                id, make, model, year_start, year_end,
                engine_displacement_cc, task_id, part_brand, part_number
            ) VALUES (
                UUID(), v_make, v_model, v_year, v_year,
                v_cc, NEW.task_id, COALESCE(NEW.part_brand, 'OEM / Generic'), TRIM(UPPER(NEW.part_number))
            )
            ON DUPLICATE KEY UPDATE
                usage_count = usage_count + 1,
                updated_at = CURRENT_TIMESTAMP(3);
        END IF;
    END IF;
END
SQL;
                        try {
                            $pdo->exec($triggerSql);
                        } catch (\Throwable $e) {
                            // ignore trigger error
                        }
                    }
                }

                // Seed tasks, OBD codes, and demo records
                foreach (['seed_tasks_and_obd.sql', 'demo_seed.sql'] as $seedFile) {
                    $filePath = $dir . '/' . $seedFile;
                    if (file_exists($filePath)) {
                        $content = file_get_contents($filePath);
                        $content = preg_replace('/\bUSE\s+[^;]+;/i', '', $content);
                        $stmts = explode(';', $content);
                        foreach ($stmts as $s) {
                            $clean = trim($s);
                            if (!empty($clean)) {
                                try {
                                    $pdo->exec($clean);
                                } catch (\Throwable $e) {
                                    // continue
                                }
                            }
                        }
                    }
                }

                error_log("CarLog MariaDB online database initialized successfully.");
            }
        } catch (\Throwable $e) {
            error_log("autoProvisionMysql note: " . $e->getMessage());
        }
    }

    /**
     * Ensures newly added tables (trips, expenses, reminders) exist and seeds demo data
     */
    public static function ensureSchemaMigrations(PDO $pdo, string $driver): void {
        try {
            if ($driver === 'sqlite') {
                $pdo->exec("
                    CREATE TABLE IF NOT EXISTS trip_logs (
                        id VARCHAR(36) PRIMARY KEY,
                        vehicle_id VARCHAR(36) NOT NULL,
                        trip_date DATE NOT NULL,
                        trip_time TIME NULL,
                        start_odometer_km INTEGER NULL,
                        end_odometer_km INTEGER NULL,
                        distance_km REAL NOT NULL,
                        purpose VARCHAR(50) NOT NULL DEFAULT 'Commute',
                        notes TEXT NULL,
                        is_deleted INTEGER NOT NULL DEFAULT 0,
                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                    );
                    CREATE TABLE IF NOT EXISTS general_expenses (
                        id VARCHAR(36) PRIMARY KEY,
                        vehicle_id VARCHAR(36) NOT NULL,
                        expense_date DATE NOT NULL,
                        expense_time TIME NULL,
                        expense_type VARCHAR(50) NOT NULL DEFAULT 'Parking',
                        amount_usd REAL NOT NULL,
                        odometer_km INTEGER NULL,
                        notes TEXT NULL,
                        receipt_photo_url VARCHAR(500) NULL,
                        is_deleted INTEGER NOT NULL DEFAULT 0,
                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                    );
                    CREATE TABLE IF NOT EXISTS vehicle_reminders (
                        id VARCHAR(36) PRIMARY KEY,
                        vehicle_id VARCHAR(36) NOT NULL,
                        reminder_title VARCHAR(150) NOT NULL,
                        reminder_category VARCHAR(50) NOT NULL DEFAULT 'Maintenance',
                        due_date DATE NULL,
                        due_odometer_km INTEGER NULL,
                        is_completed INTEGER NOT NULL DEFAULT 0,
                        completed_date DATE NULL,
                        notes TEXT NULL,
                        is_deleted INTEGER NOT NULL DEFAULT 0,
                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
                    );
                ");
            } else {
                $pdo->exec("
                    CREATE TABLE IF NOT EXISTS trip_logs (
                        id VARCHAR(36) PRIMARY KEY,
                        vehicle_id VARCHAR(36) NOT NULL,
                        trip_date DATE NOT NULL,
                        trip_time TIME NULL,
                        start_odometer_km INT UNSIGNED NULL,
                        end_odometer_km INT UNSIGNED NULL,
                        distance_km DECIMAL(8,2) NOT NULL,
                        purpose VARCHAR(50) NOT NULL DEFAULT 'Commute',
                        notes TEXT NULL,
                        is_deleted TINYINT(1) NOT NULL DEFAULT 0,
                        created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
                        updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
                        INDEX idx_trips_veh_date (vehicle_id, trip_date)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

                    CREATE TABLE IF NOT EXISTS general_expenses (
                        id VARCHAR(36) PRIMARY KEY,
                        vehicle_id VARCHAR(36) NOT NULL,
                        expense_date DATE NOT NULL,
                        expense_time TIME NULL,
                        expense_type VARCHAR(50) NOT NULL DEFAULT 'Parking',
                        amount_usd DECIMAL(10,2) NOT NULL,
                        odometer_km INT UNSIGNED NULL,
                        notes TEXT NULL,
                        receipt_photo_url VARCHAR(500) NULL,
                        is_deleted TINYINT(1) NOT NULL DEFAULT 0,
                        created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
                        updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
                        INDEX idx_expenses_veh_date (vehicle_id, expense_date)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

                    CREATE TABLE IF NOT EXISTS vehicle_reminders (
                        id VARCHAR(36) PRIMARY KEY,
                        vehicle_id VARCHAR(36) NOT NULL,
                        reminder_title VARCHAR(150) NOT NULL,
                        reminder_category VARCHAR(50) NOT NULL DEFAULT 'Maintenance',
                        due_date DATE NULL,
                        due_odometer_km INT UNSIGNED NULL,
                        is_completed TINYINT(1) NOT NULL DEFAULT 0,
                        completed_date DATE NULL,
                        notes TEXT NULL,
                        is_deleted TINYINT(1) NOT NULL DEFAULT 0,
                        created_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3),
                        updated_at TIMESTAMP(3) DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
                        INDEX idx_reminders_veh_status (vehicle_id, is_completed, due_date)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                ");
            }

            // Discover demo vehicle ID
            $firstVeh = $pdo->query("SELECT id FROM vehicles LIMIT 1")->fetchColumn();
            $demoVehId = $firstVeh ?: 'v-corolla-2022-demo';

            // Ensure demo records exist for the primary vehicle
            $stmt = $pdo->prepare("SELECT COUNT(*) FROM trip_logs WHERE vehicle_id = ?");
            $stmt->execute([$demoVehId]);
            if ((int)$stmt->fetchColumn() === 0) {
                // Trip logs
                $insTrip = $pdo->prepare("
                    INSERT INTO trip_logs (id, vehicle_id, trip_date, trip_time, start_odometer_km, end_odometer_km, distance_km, purpose, notes)
                    VALUES 
                    (?, ?, '2026-11-15', '22:28:00', 32432, 32450, 18.00, 'Commute', 'Office return trip via ring highway'),
                    (?, ?, '2026-11-12', '18:15:00', 32410, 32432, 22.00, 'Personal', 'City center groceries & weekend errands')
                ");
                $insTrip->execute(['trip-demo-1', $demoVehId, 'trip-demo-2', $demoVehId]);
            }

            $stmtExp = $pdo->prepare("SELECT COUNT(*) FROM general_expenses WHERE vehicle_id = ?");
            $stmtExp->execute([$demoVehId]);
            if ((int)$stmtExp->fetchColumn() === 0) {
                $insExp = $pdo->prepare("
                    INSERT INTO general_expenses (id, vehicle_id, expense_date, expense_time, expense_type, amount_usd, odometer_km, notes)
                    VALUES 
                    ('exp-demo-1', ?, '2026-11-13', '22:28:00', 'Parking', 12.00, 32432, 'City center underground garage 4 hrs')
                ");
                $insExp->execute([$demoVehId]);
            }

            $stmtFuel = $pdo->prepare("SELECT COUNT(*) FROM fuel_logs WHERE id = 'fuel-demo-3' OR (vehicle_id = ? AND fill_date LIKE '2026-11-14%')");
            $stmtFuel->execute([$demoVehId]);
            if ((int)$stmtFuel->fetchColumn() === 0) {
                $insertOrIgnore = ($driver === 'sqlite') ? 'INSERT OR IGNORE' : 'INSERT IGNORE';
                $insFuel = $pdo->prepare("
                    $insertOrIgnore INTO fuel_logs (id, vehicle_id, fill_date, odometer_km, fuel_liters, price_per_liter_usd, total_cost_usd, is_full_tank)
                    VALUES 
                    ('fuel-demo-3', ?, '2026-11-14 22:28:00', 32440, 22.00, 1.40, 30.80, 1)
                ");
                $insFuel->execute([$demoVehId]);
            }

            $stmtRem = $pdo->prepare("SELECT COUNT(*) FROM vehicle_reminders WHERE vehicle_id = ?");
            $stmtRem->execute([$demoVehId]);
            if ((int)$stmtRem->fetchColumn() === 0) {
                // Vehicle Reminders matching Screen 2 and Screen 5
                $insRem = $pdo->prepare("
                    INSERT INTO vehicle_reminders (id, vehicle_id, reminder_title, reminder_category, due_date, due_odometer_km, is_completed, notes)
                    VALUES 
                    (?, ?, 'Tire pressure check', 'Tires', '2026-11-18', NULL, 0, 'Check all 4 tires cold to 2.3 Bar'),
                    (?, ?, 'Registration renewal', 'Registration', '2026-11-30', NULL, 0, 'Annual vehicle inspection and registration sticker'),
                    (?, ?, 'Tire Rotation', 'Tires', '2026-12-06', 35450, 0, 'Front to back diagonal rotation'),
                    (?, ?, 'General Service', 'Maintenance', '2026-12-31', 36450, 0, 'Comprehensive multi-point inspection and fluid top-up'),
                    (?, ?, 'Brake inspection', 'Inspection', '2026-11-09', NULL, 0, 'Front and rear pad thickness check (minimum 3mm)'),
                    (?, ?, 'Insurance renewal', 'Insurance', '2026-11-13', NULL, 0, 'Comprehensive auto insurance premium renewal')
                ");
                $insRem->execute([
                    'rem-demo-1', $demoVehId,
                    'rem-demo-2', $demoVehId,
                    'rem-demo-3', $demoVehId,
                    'rem-demo-4', $demoVehId,
                    'rem-demo-5', $demoVehId,
                    'rem-demo-6', $demoVehId,
                ]);
            }

            // Tenancy partition migration: Reassign user-added vehicles to Abbas's primary Google account (abbas.chd50@gmail.com)
            $targetAbbasId = $pdo->query("SELECT id FROM users WHERE LOWER(email) LIKE '%abbas.chd50%' LIMIT 1")->fetchColumn();
            if (!$targetAbbasId) {
                $targetAbbasId = $pdo->query("SELECT id FROM users WHERE LOWER(email) LIKE '%acharafeddine%' LIMIT 1")->fetchColumn();
            }

            if ($targetAbbasId) {
                // Reassign all real user vehicles to Abbas's active account
                $pdo->prepare("
                    UPDATE vehicles 
                    SET user_id = ? 
                    WHERE id != 'c0000000-0000-0000-0000-000000000001'
                    AND vin != '2T1BURHE7NC123456'
                ")->execute([$targetAbbasId]);
            }

            // Remove duplicate seeded demo Corolla from all real user accounts
            $pdo->exec("
                DELETE FROM vehicles 
                WHERE vin = '2T1BURHE7NC123456' 
                AND user_id != 'd0000000-0000-0000-0000-000000000001'
                AND id != 'c0000000-0000-0000-0000-000000000001'
            ");

            // Clarify Demo user name to avoid confusion with real user accounts
            $pdo->exec("UPDATE users SET full_name = 'Demo Driver' WHERE id = 'd0000000-0000-0000-0000-000000000001'");
        } catch (\Throwable $e) {
            error_log('ensureSchemaMigrations note: ' . $e->getMessage());
        }
    }
}
