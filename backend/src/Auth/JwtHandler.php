<?php
declare(strict_types=1);

namespace CarLog\Auth;

use CarLog\Config\Config;
use Exception;
use RuntimeException;

/**
 * Robust JWT Handler
 * Supports firebase/php-jwt when available, with native HMAC-SHA256 fallback.
 */
class JwtHandler {
    private string $secret;
    private string $algorithm;
    private int $accessTtl;
    private int $refreshTtl;
    private string $issuer;

    public function __construct() {
        $config = Config::get()['jwt'];
        $this->secret = $config['secret'];
        $this->algorithm = $config['algorithm'];
        $this->accessTtl = $config['access_token_ttl'];
        $this->refreshTtl = $config['refresh_token_ttl'];
        $this->issuer = $config['issuer'];
    }

    public function generateTokenPair(array $userData): array {
        $now = time();

        // Access Token
        $accessPayload = [
            'iss' => $this->issuer,
            'sub' => $userData['id'],
            'email' => $userData['email'],
            'full_name' => $userData['full_name'],
            'type' => 'access',
            'iat' => $now,
            'exp' => $now + $this->accessTtl,
        ];

        // Refresh Token
        $refreshPayload = [
            'iss' => $this->issuer,
            'sub' => $userData['id'],
            'type' => 'refresh',
            'iat' => $now,
            'exp' => $now + $this->refreshTtl,
        ];

        return [
            'access_token' => $this->encode($accessPayload),
            'refresh_token' => $this->encode($refreshPayload),
            'expires_in' => $this->accessTtl,
            'token_type' => 'Bearer',
        ];
    }

    public function decode(string $token): array {
        // If firebase/php-jwt exists, we can use it, or use the robust fallback
        if (class_exists('\Firebase\JWT\JWT') && class_exists('\Firebase\JWT\Key')) {
            try {
                $decoded = \Firebase\JWT\JWT::decode($token, new \Firebase\JWT\Key($this->secret, $this->algorithm));
                return (array)$decoded;
            } catch (Exception $e) {
                throw new RuntimeException("Invalid token: " . $e->getMessage());
            }
        }

        return $this->nativeDecode($token);
    }

    public function encode(array $payload): string {
        if (class_exists('\Firebase\JWT\JWT')) {
            return \Firebase\JWT\JWT::encode($payload, $this->secret, $this->algorithm);
        }

        return $this->nativeEncode($payload);
    }

    private function nativeEncode(array $payload): string {
        $header = ['typ' => 'JWT', 'alg' => 'HS256'];
        
        $base64UrlHeader = $this->base64UrlEncode(json_encode($header));
        $base64UrlPayload = $this->base64UrlEncode(json_encode($payload));
        
        $signature = hash_hmac('sha256', "{$base64UrlHeader}.{$base64UrlPayload}", $this->secret, true);
        $base64UrlSignature = $this->base64UrlEncode($signature);
        
        return "{$base64UrlHeader}.{$base64UrlPayload}.{$base64UrlSignature}";
    }

    private function nativeDecode(string $jwt): array {
        $parts = explode('.', $jwt);
        if (count($parts) !== 3) {
            throw new RuntimeException("Malformed JWT structure");
        }

        [$headerB64, $payloadB64, $sigB64] = $parts;
        $expectedSig = $this->base64UrlEncode(
            hash_hmac('sha256', "{$headerB64}.{$payloadB64}", $this->secret, true)
        );

        if (!hash_equals($expectedSig, $sigB64)) {
            throw new RuntimeException("Signature verification failed");
        }

        $payloadJson = $this->base64UrlDecode($payloadB64);
        $payload = json_decode($payloadJson, true);
        if (!is_array($payload)) {
            throw new RuntimeException("Invalid JWT payload JSON");
        }

        if (isset($payload['exp']) && $payload['exp'] < time()) {
            throw new RuntimeException("Token has expired");
        }

        return $payload;
    }

    private function base64UrlEncode(string $data): string {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }

    private function base64UrlDecode(string $data): string {
        return base64_decode(strtr($data, '-_', '+/'));
    }
}
