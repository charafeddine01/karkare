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
}
