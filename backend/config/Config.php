<?php
declare(strict_types=1);

namespace CarLog\Config;

/**
 * CarLog Application Configuration
 * Optimized for shared hosting environments (cPanel/LiteSpeed)
 */
class Config {
    public static function get(): array {
        return [
            'app' => [
                'name' => 'CarLog',
                'base_url' => getenv('CARLOG_BASE_URL') ?: 'https://carlog.charafeddine.xyz',
                'environment' => getenv('CARLOG_ENV') ?: 'production',
                'debug' => (bool)(getenv('CARLOG_DEBUG') ?: false),
                'timezone' => 'UTC',
            ],
            'database' => [
                'host' => getenv('DB_HOST') ?: '127.0.0.1',
                'port' => (int)(getenv('DB_PORT') ?: 3306),
                'dbname' => getenv('DB_NAME') ?: 'carlog_db',
                'user' => getenv('DB_USER') ?: 'carlog_user',
                'password' => getenv('DB_PASS') ?: 'secret_carlog_password_2026',
                'charset' => 'utf8mb4',
                'collation' => 'utf8mb4_unicode_ci',
            ],
            'jwt' => [
                'secret' => getenv('JWT_SECRET') ?: 'karkare_carlog_super_secure_jwt_key_2026_metric_garage_token',
                'algorithm' => 'HS256',
                'access_token_ttl' => 86400, // 24 hours
                'refresh_token_ttl' => 2592000, // 30 days
                'issuer' => 'carlog-api',
            ],
            'smtp' => [
                'host' => getenv('SMTP_HOST') ?: 'mail.charafeddine.xyz',
                'port' => (int)(getenv('SMTP_PORT') ?: 465), // SSL 465 or TLS 587
                'username' => getenv('SMTP_USER') ?: 'noreply@carlog.charafeddine.xyz',
                'password' => getenv('SMTP_PASS') ?: 'SecureMailPass123!',
                'encryption' => getenv('SMTP_ENCRYPT') ?: 'ssl', // ssl or tls
                'from_email' => getenv('SMTP_FROM') ?: 'noreply@carlog.charafeddine.xyz',
                'from_name' => 'CarLog Garage Verification',
                'otp_validity_minutes' => 15,
            ],
            'storage' => [
                'uploads_dir' => realpath(__DIR__ . '/../uploads') ?: (__DIR__ . '/../uploads'),
                'max_photo_bytes' => 10 * 1024 * 1024, // 10MB
                'max_audio_bytes' => 5 * 1024 * 1024,  // 5MB
                'allowed_photo_mimes' => [
                    'image/jpeg', 'image/png', 'image/webp'
                ],
                'allowed_audio_mimes' => [
                    'audio/m4a', 'audio/mp4', 'audio/x-m4a', 'audio/aac', 'audio/mpeg'
                ],
            ],
        ];
    }
}
