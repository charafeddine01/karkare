<?php
declare(strict_types=1);

namespace CarLog\Controllers;

use CarLog\Config\Config;
use CarLog\Router\Request;
use CarLog\Router\Response;
use Throwable;

class UploadController {
    public function upload(Request $request): void {
        $userId = $request->getUserId();
        $vehicleId = (string)$request->get('vehicle_id', 'general');
        $uploadType = (string)$request->get('type', 'photo'); // photo | audio

        $files = $request->getFiles();
        if (empty($files['file']) || !is_array($files['file'])) {
            Response::error('No file provided in form-data key "file"', 'NO_FILE', 400);
            return;
        }

        $file = $files['file'];
        if ($file['error'] !== UPLOAD_ERR_OK) {
            Response::error('File upload error code: ' . $file['error'], 'UPLOAD_ERROR', 400);
            return;
        }

        $storageConfig = Config::get()['storage'];
        $appConfig = Config::get()['app'];

        // Clean vehicleId to prevent directory traversal
        $vehicleId = preg_replace('/[^a-zA-Z0-9_\-]/', '', $vehicleId) ?: 'general';
        $targetDir = rtrim($storageConfig['uploads_dir'], '/') . "/{$userId}/{$vehicleId}";

        if (!is_dir($targetDir)) {
            if (!mkdir($targetDir, 0755, true)) {
                Response::error('Failed to create upload destination directory', 'STORAGE_ERROR', 500);
                return;
            }
        }

        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);

        $fileSize = (int)$file['size'];
        $uuid = bin2hex(random_bytes(16));

        if ($uploadType === 'audio') {
            if (!in_array($mimeType, $storageConfig['allowed_audio_mimes'], true)) {
                Response::error("Invalid audio format: {$mimeType}. Allowed: m4a, mp4, aac", 'INVALID_MIME', 400);
                return;
            }
            if ($fileSize > $storageConfig['max_audio_bytes']) {
                Response::error('Audio file exceeds maximum 5MB limit', 'FILE_TOO_LARGE', 400);
                return;
            }

            $extension = 'm4a';
            $filename = "{$uuid}.{$extension}";
            $destination = "{$targetDir}/{$filename}";

            if (!move_uploaded_file($file['tmp_name'], $destination)) {
                Response::error('Failed to save audio file', 'STORAGE_ERROR', 500);
                return;
            }
        } else {
            // Photo upload
            if (!in_array($mimeType, $storageConfig['allowed_photo_mimes'], true)) {
                Response::error("Invalid image format: {$mimeType}. Allowed: jpeg, png, webp", 'INVALID_MIME', 400);
                return;
            }
            if ($fileSize > $storageConfig['max_photo_bytes']) {
                Response::error('Image file exceeds maximum 10MB limit', 'FILE_TOO_LARGE', 400);
                return;
            }

            $extension = 'webp';
            $filename = "{$uuid}.{$extension}";
            $destination = "{$targetDir}/{$filename}";

            // Optimize/convert to WebP if GD is supported, otherwise standard move
            if (function_exists('imagecreatefromstring') && function_exists('imagewebp')) {
                try {
                    $imageData = file_get_contents($file['tmp_name']);
                    $src = imagecreatefromstring($imageData);
                    if ($src !== false) {
                        // Max dimension 1920px for high-res garage photos
                        $width = imagesx($src);
                        $height = imagesy($src);
                        $maxDim = 1920;

                        if ($width > $maxDim || $height > $maxDim) {
                            if ($width > $height) {
                                $newWidth = $maxDim;
                                $newHeight = (int)($height * ($maxDim / $width));
                            } else {
                                $newHeight = $maxDim;
                                $newWidth = (int)($width * ($maxDim / $height));
                            }
                            $dst = imagecreatetruecolor($newWidth, $newHeight);
                            imagealphablending($dst, false);
                            imagesavealpha($dst, true);
                            imagecopyresampled($dst, $src, 0, 0, 0, 0, $newWidth, $newHeight, $width, $height);
                            imagedestroy($src);
                            $src = $dst;
                        }

                        imagewebp($src, $destination, 85);
                        imagedestroy($src);
                    } else {
                        move_uploaded_file($file['tmp_name'], $destination);
                    }
                } catch (Throwable $e) {
                    move_uploaded_file($file['tmp_name'], $destination);
                }
            } else {
                $ext = pathinfo($file['name'], PATHINFO_EXTENSION) ?: 'jpg';
                $filename = "{$uuid}.{$ext}";
                $destination = "{$targetDir}/{$filename}";
                move_uploaded_file($file['tmp_name'], $destination);
            }
        }

        $relativePath = "/uploads/{$userId}/{$vehicleId}/{$filename}";
        $mediaUrl = rtrim($appConfig['base_url'], '/') . "/api/media/{$userId}/{$vehicleId}/{$filename}";

        Response::success([
            'file_name' => $filename,
            'relative_path' => $relativePath,
            'url' => $mediaUrl,
            'size_bytes' => file_exists($destination) ? filesize($destination) : $fileSize,
        ], 'File uploaded successfully.', 201);
    }

    /**
     * Stream uploaded media files with proper MIME and caching headers
     */
    public function streamMedia(Request $request): void {
        $userId = preg_replace('/[^a-zA-Z0-9_\-]/', '', (string)$request->getParam('userId'));
        $vehicleId = preg_replace('/[^a-zA-Z0-9_\-]/', '', (string)$request->getParam('vehicleId'));
        $filename = basename((string)$request->getParam('filename'));

        $storageConfig = Config::get()['storage'];
        $file = rtrim($storageConfig['uploads_dir'], '/') . "/{$userId}/{$vehicleId}/{$filename}";

        if (!file_exists($file) || !is_file($file)) {
            http_response_code(404);
            header('Content-Type: application/json');
            echo json_encode(['success' => false, 'error' => 'Media file not found']);
            return;
        }

        $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        $mimes = [
            'webp' => 'image/webp',
            'jpg'  => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png'  => 'image/png',
            'gif'  => 'image/gif',
            'm4a'  => 'audio/mp4',
            'mp4'  => 'video/mp4',
            'pdf'  => 'application/pdf',
        ];

        header('Content-Type: ' . ($mimes[$ext] ?? 'application/octet-stream'));
        header('Cache-Control: public, max-age=31536000');
        header('Content-Length: ' . (string)filesize($file));
        readfile($file);
        exit;
    }
}
