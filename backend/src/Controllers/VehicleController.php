<?php
declare(strict_types=1);

namespace CarLog\Controllers;

use CarLog\Config\Config;
use CarLog\Config\Database;
use CarLog\Router\Request;
use CarLog\Router\Response;
use PDO;
use Throwable;

class VehicleController {
    private PDO $db;

    public function __construct() {
        $this->db = Database::getConnection();
    }

    public function generateShareToken(Request $request): void {
        $userId = $request->getUserId();
        $vehicleId = $request->getParam('id');
        $hideCosts = (int)$request->get('hide_costs', 1);

        try {
            // Verify vehicle ownership
            $stmt = $this->db->prepare("SELECT id, public_share_token FROM vehicles WHERE id = ? AND user_id = ? AND is_deleted = 0 LIMIT 1");
            $stmt->execute([$vehicleId, $userId]);
            $vehicle = $stmt->fetch();

            if (!$vehicle) {
                Response::error('Vehicle not found or unauthorized', 'NOT_FOUND', 404);
                return;
            }

            $token = $vehicle['public_share_token'];
            if (empty($token)) {
                $token = bin2hex(random_bytes(24));
            }

            $update = $this->db->prepare(
                "UPDATE vehicles SET public_share_token = ?, hide_costs_on_share = ?, updated_at = CURRENT_TIMESTAMP(3) WHERE id = ?"
            );
            $update->execute([$token, $hideCosts, $vehicleId]);

            $baseUrl = rtrim(Config::get()['app']['base_url'], '/');
            $shareUrl = "{$baseUrl}/v/{$token}";

            Response::success([
                'public_share_token' => $token,
                'share_url' => $shareUrl,
                'hide_costs_on_share' => (bool)$hideCosts,
            ], 'Share link generated successfully.');

        } catch (Throwable $e) {
            error_log("Share token generation error: " . $e->getMessage());
            Response::error('Failed to generate share link: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }
}
