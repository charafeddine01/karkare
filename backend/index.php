<?php
declare(strict_types=1);

/**
 * CarLog Universal Master Router
 * Works seamlessly on LiteSpeed and Apache in domain root or subfolder (/karkare/)
 */

$rawUri = $_SERVER['REQUEST_URI'] ?? '/';
$uri = (string)parse_url($rawUri, PHP_URL_PATH);

// Strip subfolder prefix if present
if (str_starts_with($uri, '/karkare')) {
    $uri = substr($uri, strlen('/karkare'));
    if ($uri === '' || $uri === false) {
        $uri = '/';
    }
}

// 1. Digital Service Book Public Viewer (/v/{token})
if (preg_match('#^/v/([a-zA-Z0-9_\-]+)#', $uri, $matches)) {
    $_GET['token'] = $matches[1];
    require __DIR__ . '/public/view.php';
    exit;
}

// 2. Webhook (/webhook)
if (str_starts_with($uri, '/webhook')) {
    require __DIR__ . '/public/webhook.php';
    exit;
}

// 3. Static Uploads
if (str_starts_with($uri, '/uploads/')) {
    $file = __DIR__ . $uri;
    if (is_file($file)) {
        $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        $mimes = [
            'webp' => 'image/webp',
            'jpg'  => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png'  => 'image/png',
            'm4a'  => 'audio/mp4',
            'pdf'  => 'application/pdf',
        ];
        if (isset($mimes[$ext])) {
            header('Content-Type: ' . $mimes[$ext]);
            readfile($file);
            exit;
        }
    }
}

// 4. API and Everything else -> public/index.php
require __DIR__ . '/public/index.php';
