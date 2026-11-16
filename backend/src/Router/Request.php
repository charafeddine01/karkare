<?php
declare(strict_types=1);

namespace CarLog\Router;

class Request {
    private string $method;
    private string $path;
    private array $headers;
    private array $queryParams;
    private array $body;
    private array $files;
    private array $params = [];
    private ?array $user = null;

    public function __construct() {
        $this->method = strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
        
        $requestUri = $_SERVER['REQUEST_URI'] ?? '/';
        $uriParts = explode('?', $requestUri, 2);
        $path = rtrim($uriParts[0], '/') ?: '/';

        // Automatically normalize subfolder if deployed under a subdirectory (e.g. /karkare)
        if (str_starts_with($path, '/karkare')) {
            $path = substr($path, strlen('/karkare'));
            $path = rtrim($path, '/') ?: '/';
        }

        $rawScript = $_SERVER['SCRIPT_NAME'] ?? '';
        if (str_ends_with($rawScript, '.php')) {
            $scriptDir = dirname($rawScript);
            $baseDir = preg_replace('#/public$#', '', $scriptDir);
            if (!empty($baseDir) && $baseDir !== '/' && str_starts_with($path, $baseDir)) {
                $path = substr($path, strlen($baseDir));
                $path = rtrim($path, '/') ?: '/';
            }
        }

        $this->path = $path;
        
        $this->queryParams = $_GET;
        $this->files = $_FILES;
        $this->headers = $this->extractHeaders();
        $this->body = $this->parseBody();
    }

    private function extractHeaders(): array {
        $headers = [];
        foreach ($_SERVER as $key => $value) {
            if (str_starts_with($key, 'HTTP_')) {
                $header = strtolower(str_replace('_', '-', substr($key, 5)));
                $headers[$header] = $value;
            } elseif (in_array($key, ['CONTENT_TYPE', 'CONTENT_LENGTH', 'AUTHORIZATION'], true)) {
                $header = strtolower(str_replace('_', '-', $key));
                $headers[$header] = $value;
            }
        }
        // LiteSpeed / Apache Authorization header fallback
        if (!isset($headers['authorization'])) {
            if (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
                $headers['authorization'] = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
            } elseif (function_exists('apache_request_headers')) {
                $apacheHeaders = apache_request_headers();
                if (isset($apacheHeaders['Authorization'])) {
                    $headers['authorization'] = $apacheHeaders['Authorization'];
                }
            }
        }
        return $headers;
    }

    private function parseBody(): array {
        if ($this->method === 'GET') {
            return [];
        }

        $contentType = $this->getHeader('content-type') ?? '';
        if (str_contains($contentType, 'application/json')) {
            $rawInput = file_get_contents('php://input');
            if (!empty($rawInput)) {
                $decoded = json_decode($rawInput, true);
                if (is_array($decoded)) {
                    return $decoded;
                }
            }
            return [];
        }

        return $_POST;
    }

    public function getMethod(): string {
        return $this->method;
    }

    public function getPath(): string {
        return $this->path;
    }

    public function getHeader(string $name): ?string {
        $normalized = strtolower($name);
        return $this->headers[$normalized] ?? null;
    }

    public function getBearerToken(): ?string {
        $authHeader = $this->getHeader('authorization');
        if ($authHeader && preg_match('/Bearer\s+(\S+)/i', $authHeader, $matches)) {
            return $matches[1];
        }
        return null;
    }

    public function getQuery(string $key, mixed $default = null): mixed {
        return $this->queryParams[$key] ?? $default;
    }

    public function getAllQueries(): array {
        return $this->queryParams;
    }

    public function getBody(): array {
        return $this->body;
    }

    public function setBody(array $body): void {
        $this->body = $body;
    }

    public function get(string $key, mixed $default = null): mixed {
        return $this->body[$key] ?? $this->queryParams[$key] ?? $default;
    }

    public function getFiles(): array {
        return $this->files;
    }

    public function setParams(array $params): void {
        $this->params = $params;
    }

    public function getParam(string $name, mixed $default = null): mixed {
        return $this->params[$name] ?? $default;
    }

    public function setUser(?array $user): void {
        $this->user = $user;
    }

    public function getUser(): ?array {
        return $this->user;
    }

    public function getUserId(): ?string {
        return $this->user['id'] ?? null;
    }
}
