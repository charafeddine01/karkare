<?php
declare(strict_types=1);

// =============================================================================
// CarLog Auto-Deploy Webhook Endpoint
// URL: https://charafeddine.xyz/karkare/webhook.php
// Triggers automatic git pull / sync when a GitHub push event is received
// =============================================================================

header('Content-Type: application/json; charset=utf-8');

$secret = getenv('DEPLOY_WEBHOOK_SECRET') ?: 'karkare_deploy_secret_2026';

// Verify GitHub HMAC-SHA256 signature if secret is set
$signatureHeader = $_SERVER['HTTP_X_HUB_SIGNATURE_256'] ?? '';
$payload = file_get_contents('php://input');

if (!empty($secret) && !empty($signatureHeader)) {
    $expectedSignature = 'sha256=' . hash_hmac('sha256', $payload, $secret);
    if (!hash_equals($expectedSignature, $signatureHeader)) {
        http_response_code(403);
        echo json_encode(['success' => false, 'error' => 'Invalid webhook signature']);
        exit;
    }
}

// Execute git pull if inside a git repository
$repoDir = dirname(__DIR__, 2);
if (is_dir($repoDir . '/.git')) {
    $output = [];
    $returnVar = 0;
    exec("cd " . escapeshellarg($repoDir) . " && git pull origin main 2>&1", $output, $returnVar);

    echo json_encode([
        'success' => $returnVar === 0,
        'action' => 'git_pull',
        'output' => $output,
        'timestamp' => date('c'),
    ]);
    exit;
}

echo json_encode([
    'success' => true,
    'message' => 'Webhook received. Ready for deployment.',
    'timestamp' => date('c'),
]);
