<?php
declare(strict_types=1);

namespace CarLog\Config;

use PDO;
use PDOException;
use RuntimeException;

/**
 * Database Singleton Connection Handler
 * Supports MariaDB / MySQL with zero-configuration fallback to SQLite
 */
class Database {
    private static ?PDO $instance = null;
    private static string $driver = 'mysql';

    private function __construct() {}
    private function __clone() {}

    public static function getConnection(): PDO {
        if (self::$instance === null) {
            $config = Config::get()['database'];
            
            // 1. Try MySQL/MariaDB PDO
            $mysqlError = null;
            if (!empty($config['host']) && !empty($config['dbname'])) {
                try {
                    $dsn = sprintf(
                        'mysql:host=%s;port=%d;dbname=%s;charset=%s',
                        $config['host'],
                        $config['port'],
                        $config['dbname'],
                        $config['charset']
                    );

                    $options = [
                        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                        PDO::ATTR_EMULATE_PREPARES => false,
                        1002 => "SET NAMES {$config['charset']} COLLATE {$config['collation']}",
                    ];

                    self::$instance = new PDO($dsn, $config['user'], $config['password'], $options);
                    self::$driver = 'mysql';
                    return self::$instance;
                } catch (PDOException $e) {
                    $mysqlError = $e->getMessage();
                }
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
}
