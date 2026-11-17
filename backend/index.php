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

// 3. API Routes (/api/...)
if (str_starts_with($uri, '/api')) {
    require __DIR__ . '/public/index.php';
    exit;
}

// 4. Static Uploads Streaming
if (str_starts_with($uri, '/uploads/')) {
    $file = __DIR__ . $uri;
    if (file_exists($file) && is_file($file)) {
        $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
        $mimes = [
            'webp' => 'image/webp',
            'jpg'  => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png'  => 'image/png',
            'gif'  => 'image/gif',
            'm4a'  => 'audio/mp4',
            'pdf'  => 'application/pdf',
        ];
        if (isset($mimes[$ext])) {
            header('Content-Type: ' . $mimes[$ext]);
            header('Cache-Control: public, max-age=31536000');
            header('Content-Length: ' . (string)filesize($file));
            readfile($file);
            exit;
        }
    }
    http_response_code(404);
    echo "Media file not found";
    exit;
}

// 5. Web Application Front Controller (Login, Register, Dashboard, /app, /login, or /)
header('Content-Type: text/html; charset=UTF-8');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
header('Expires: 0');
header('X-LiteSpeed-Cache-Control: no-cache');
readfile(__DIR__ . '/public/app.html');
exit;
