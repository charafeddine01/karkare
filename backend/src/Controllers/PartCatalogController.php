<?php
declare(strict_types=1);

namespace CarLog\Controllers;

use CarLog\Config\Database;
use CarLog\Router\Request;
use CarLog\Router\Response;
use PDO;
use Throwable;

class PartCatalogController {
    private PDO $db;

    public function __construct() {
        $this->db = Database::getConnection();
    }

    /**
     * Tier 2 Crowdsourced Part Suggestion Endpoint
     */
    public function suggest(Request $request): void {
        $make = trim((string)$request->getQuery('make', ''));
        $model = trim((string)$request->getQuery('model', ''));
        $year = (int)$request->getQuery('year', 0);
        $cc = (int)$request->getQuery('displacement_cc', 0);
        $taskId = trim((string)$request->getQuery('task_id', ''));

        if (empty($taskId)) {
            Response::error('task_id query parameter is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $sql = "SELECT id, make, model, year_start, year_end, engine_displacement_cc,
                           task_id, part_brand, part_number, specs_note, usage_count, verified_by_admin
                    FROM vehicle_part_catalog
                    WHERE task_id = :task_id";
            $params = [':task_id' => $taskId];

            if (!empty($make)) {
                $sql .= " AND LOWER(make) = LOWER(:make)";
                $params[':make'] = $make;
            }

            if (!empty($model)) {
                $sql .= " AND LOWER(model) LIKE LOWER(:model)";
                $params[':model'] = '%' . $model . '%';
            }

            if ($year > 0) {
                $sql .= " AND (:year BETWEEN year_start AND year_end OR year_start = 0)";
                $params[':year'] = $year;
            }

            if ($cc > 0) {
                // Within 100cc tolerance for engine variants
                $sql .= " AND (ABS(engine_displacement_cc - :cc) <= 100 OR engine_displacement_cc = 0)";
                $params[':cc'] = $cc;
            }

            $sql .= " ORDER BY verified_by_admin DESC, usage_count DESC LIMIT 20";

            $stmt = $this->db->prepare($sql);
            $stmt->execute($params);
            $rows = $stmt->fetchAll();

            $suggestions = array_map(function ($row) {
                $count = (int)$row['usage_count'];
                return [
                    'id' => $row['id'],
                    'part_brand' => $row['part_brand'],
                    'part_number' => $row['part_number'],
                    'specs_note' => $row['specs_note'],
                    'usage_count' => $count,
                    'verified_by_admin' => (bool)$row['verified_by_admin'],
                    'badge' => "Community verified (Used {$count} " . ($count === 1 ? 'time' : 'times') . ")",
                    'tier' => 2,
                ];
            }, $rows);

            Response::success($suggestions, 'Part suggestions retrieved.');
        } catch (Throwable $e) {
            error_log("Part suggestion error: " . $e->getMessage());
            Response::error('Failed to retrieve part suggestions: ' . $e->getMessage(), 'DATABASE_ERROR', 500);
        }
    }

    /**
     * Search OBD-II codes
     */
    public function searchObd(Request $request): void {
        $code = strtoupper(trim((string)$request->getQuery('code', '')));

        if (empty($code)) {
            Response::error('OBD code is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $stmt = $this->db->prepare("SELECT * FROM obd_codes_catalog WHERE code = ? OR code LIKE ? LIMIT 10");
            $stmt->execute([$code, "{$code}%"]);
            $results = $stmt->fetchAll();

            Response::success($results, 'OBD search results.');
        } catch (Throwable $e) {
            Response::error('OBD query failed', 'DATABASE_ERROR', 500);
        }
    }
}
