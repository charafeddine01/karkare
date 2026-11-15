<?php
// Local Development Server Router for PHP Built-in Server
$uri = urldecode(parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));

// Serve static uploads
if (str_starts_with($uri, '/uploads/')) {
    $filePath = __DIR__ . $uri;
    if (file_exists($filePath) && is_file($filePath)) {
        return false;
    }
}

// Serve public static files
$publicFile = __DIR__ . '/public' . $uri;
if ($uri !== '/' && file_exists($publicFile) && is_file($publicFile)) {
    return false;
}

// Route /v/{token}
if (preg_match('#^/v/([a-zA-Z0-9_\-]+)/?$#', $uri, $matches)) {
    $_GET['token'] = $matches[1];
    require __DIR__ . '/public/view.php';
    return true;
}

// Route API and everything else through public/index.php
require __DIR__ . '/public/index.php';
return true;
