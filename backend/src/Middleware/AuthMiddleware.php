<?php
declare(strict_types=1);

namespace CarLog\Middleware;

use CarLog\Auth\JwtHandler;
use CarLog\Config\Database;
use CarLog\Router\Request;
use CarLog\Router\Response;
use Throwable;

class AuthMiddleware {
    public static function handle(Request $request): bool {
        $token = $request->getBearerToken();
        if (!$token) {
            Response::error("Authorization Bearer token required", "UNAUTHORIZED", 401);
            return false;
        }

        try {
            $jwtHandler = new JwtHandler();
            $payload = $jwtHandler->decode($token);

            if (($payload['type'] ?? '') !== 'access') {
                Response::error("Invalid token type", "UNAUTHORIZED", 401);
                return false;
            }

            $userId = $payload['sub'] ?? null;
            if (!$userId) {
                Response::error("Invalid token subject", "UNAUTHORIZED", 401);
                return false;
            }

            $db = Database::getConnection();
            $stmt = $db->prepare("SELECT id, email, full_name, is_email_verified FROM users WHERE id = ? LIMIT 1");
            $stmt->execute([$userId]);
            $user = $stmt->fetch();

            if (!$user) {
                Response::error("User account not found or deactivated", "UNAUTHORIZED", 401);
                return false;
            }

            $request->setUser($user);
            return true;
        } catch (Throwable $e) {
            Response::error("Token verification failed: " . $e->getMessage(), "UNAUTHORIZED", 401);
            return false;
        }
    }
}
