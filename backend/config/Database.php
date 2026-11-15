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
                for ($i = 0; $i < 6; $i++) {
                    $searchDir = dirname($searchDir);
                    $cnfPath = $searchDir . '/.my.cnf';
                    if (file_exists($cnfPath) && is_readable($cnfPath)) {
                        $parsed = @parse_ini_file($cnfPath, true);
                        if ($parsed) {
                            $foundCnf = $cnfPath;
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

                // Check common Unix domain sockets
                $commonSockets = ['/var/run/mysqld/mysqld.sock', '/run/mysqld/mysqld.sock', '/tmp/mysql.sock', '/var/lib/mysql/mysql.sock'];
                foreach ($commonSockets as $sock) {
                    if (file_exists($sock)) {
                        $candidateDsns[] = sprintf('mysql:unix_socket=%s;dbname=%s;charset=%s', $sock, $config['dbname'], $config['charset']);
                    }
                }

                // TCP hosts
                $candidateDsns[] = sprintf('mysql:host=%s;port=%d;dbname=%s;charset=%s', $config['host'], $config['port'], $config['dbname'], $config['charset']);
                $candidateDsns[] = sprintf('mysql:host=localhost;port=3306;dbname=%s;charset=%s', $config['dbname'], $config['charset']);
                $candidateDsns[] = sprintf('mysql:host=127.0.0.1;port=3306;dbname=%s;charset=%s', $config['dbname'], $config['charset']);

                $candidateDsns = array_unique($candidateDsns);

                foreach ($candidateDsns as $dsn) {
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

                        $pdo = new PDO($dsn, $config['user'], $config['password'], $options);
                        self::$driver = 'mysql';
                        self::autoProvisionMysql($pdo);
                        self::$instance = $pdo;
                        self::$lastError = "Connected via: {$dsn}" . ($foundCnf ? " (cnf: {$foundCnf})" : "");
                        return self::$instance;
                    } catch (PDOException $e) {
                        $mysqlError = "DSN [{$dsn}] error: " . $e->getMessage();
                    }
                }
                self::$lastError = $mysqlError . ($foundCnf ? " (found cnf at {$foundCnf})" : " (no cnf found)");
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
                $seedFile = $dir . '/seed_tasks_and_obd.sql';
                $demoFile = $dir . '/demo_seed.sql';

                if (file_exists($schemaFile)) {
                    $sql = file_get_contents($schemaFile);
                    $sql = preg_replace('/CREATE DATABASE[^;]+;/i', '', $sql);
                    $sql = preg_replace('/USE[^;]+;/i', '', $sql);
                    $sql = preg_replace('/DELIMITER\s+\$\$/i', '', $sql);
                    $sql = preg_replace('/DELIMITER\s+;/i', '', $sql);
                    $sql = str_replace('$$', ';', $sql);
                    $pdo->exec($sql);
                }

                if (file_exists($seedFile)) {
                    $seed = file_get_contents($seedFile);
                    $seed = preg_replace('/USE[^;]+;/i', '', $seed);
                    $pdo->exec($seed);
                }

                if (file_exists($demoFile)) {
                    $demo = file_get_contents($demoFile);
                    $demo = preg_replace('/USE[^;]+;/i', '', $demo);
                    $pdo->exec($demo);
                }

                error_log("CarLog MariaDB auto-provisioning completed successfully.");
            }
        } catch (\Throwable $e) {
            error_log("autoProvisionMysql note: " . $e->getMessage());
        }
    }
}
