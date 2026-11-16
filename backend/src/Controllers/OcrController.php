<?php
declare(strict_types=1);

namespace CarLog\Controllers;

use CarLog\Router\Request;
use CarLog\Router\Response;
use Throwable;

class OcrController {
    private const OCR_API_KEY = 'K88924823988957';
    private const OCR_API_URL = 'https://api.ocr.space/parse/image';

    /**
     * Process high-accuracy online Cloud Neural OCR
     * Route: POST /api/ocr/scan
     */
    public function scan(Request $request): void {
        $b = $request->getBody();
        $imageData = $b['image'] ?? null;
        $mode = strtolower(trim((string)($b['mode'] ?? 'vin')));

        if (empty($imageData)) {
            Response::error('Image payload (base64) is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            // Normalize base64 image data URI
            if (!str_starts_with($imageData, 'data:image/')) {
                $imageData = 'data:image/jpeg;base64,' . $imageData;
            }

            $postData = [
                'apikey' => self::OCR_API_KEY,
                'language' => 'eng',
                'OCREngine' => '2', // Deep Learning Neural Network Engine
                'isOverlayRequired' => 'false',
                'scale' => 'true',
                'detectOrientation' => 'true',
                'base64Image' => $imageData,
            ];

            $ch = curl_init(self::OCR_API_URL);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($postData));
            curl_setopt($ch, CURLOPT_TIMEOUT, 15);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);

            $rawResponse = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

            if ($rawResponse === false || $httpCode !== 200) {
                // Fallback attempt with Engine 1
                $postData['OCREngine'] = '1';
                curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($postData));
                $rawResponse = curl_exec($ch);
            }

            if ($rawResponse === false) {
                Response::error('Cloud OCR service timed out. Please retry or enter manually.', 'GATEWAY_TIMEOUT', 504);
                return;
            }

            $decoded = json_decode($rawResponse, true);
            $parsedText = '';
            if (!empty($decoded['ParsedResults'][0]['ParsedText'])) {
                $parsedText = (string)$decoded['ParsedResults'][0]['ParsedText'];
            }

            $extractedValue = $this->extractTargetValue($parsedText, $mode);

            Response::success([
                'raw_text' => trim($parsedText),
                'extracted_value' => $extractedValue,
                'mode' => $mode,
                'engine' => 'cloud_neural_engine_2',
                'is_valid_vin' => ($mode === 'vin') ? $this->isValidVin($extractedValue) : null,
            ], 'Cloud Neural OCR processed successfully.');

        } catch (Throwable $e) {
            error_log("Cloud OCR processing error: " . $e->getMessage());
            Response::error('OCR processing failed: ' . $e->getMessage(), 'SERVER_ERROR', 500);
        }
    }

    /**
     * Clean and extract target pattern (VIN, Odometer, Part Number)
     */
    private function extractTargetValue(string $rawText, string $mode): string {
        $raw = trim($rawText);
        if (empty($raw)) {
            return '';
        }

        if ($mode === 'vin') {
            return $this->parseVin($raw);
        }

        if ($mode === 'odometer') {
            if (preg_match_all('/\b\d{2,7}\b/', $raw, $matches)) {
                $valid = array_filter(array_map('intval', $matches[0]), fn($n) => $n >= 10 && $n <= 2000000);
                if (!empty($valid)) {
                    return (string)reset($valid);
                }
            }
            return '';
        }

        if ($mode === 'part_number') {
            $lines = array_filter(array_map('trim', explode("\n", $raw)));
            foreach ($lines as $line) {
                $cleaned = preg_replace('/[^A-Za-z0-9\-\/\.\s]/', '', $line);
                if (strlen($cleaned) >= 3 && strlen($cleaned) <= 25 && preg_match('/\d/', $cleaned)) {
                    return strtoupper(trim($cleaned));
                }
            }
            return strtoupper(preg_replace('/[^A-Za-z0-9\-\/\.]/', '', $lines[0] ?? ''));
        }

        return $raw;
    }

    /**
     * Strict ISO-3779 VIN extraction and character normalization
     */
    private function parseVin(string $text): string {
        $clean = strtoupper($text);
        $clean = preg_replace('/(VIN|CHASSIS|IDENTIFICATION|NUMBER|NO)[:.\s-]*/i', '', $clean);

        if (preg_match_all('/[A-Z0-9]{15,18}/', preg_replace('/[^A-Z0-9]/', '', $clean), $matches)) {
            foreach ($matches[0] as $candidate) {
                if (strlen($candidate) >= 17) {
                    $vin17 = substr($candidate, 0, 17);
                    $vin17 = strtr($vin17, ['I' => '1', 'O' => '0', 'Q' => '0']);
                    return $vin17;
                }
            }
        }

        $tokens = preg_split('/\s+/', $clean);
        foreach ($tokens as $token) {
            $alphanumeric = preg_replace('/[^A-Z0-9]/', '', $token);
            if (strlen($alphanumeric) >= 17) {
                $vin17 = substr($alphanumeric, 0, 17);
                return strtr($vin17, ['I' => '1', 'O' => '0', 'Q' => '0']);
            }
        }

        return '';
    }

    /**
     * Check if string meets basic 17-char VIN requirements
     */
    private function isValidVin(string $vin): bool {
        return (bool)preg_match('/^[A-HJ-NPR-Z0-9]{17}$/', $vin);
    }
}
