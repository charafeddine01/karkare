<?php
declare(strict_types=1);

namespace CarLog\Router;

use Throwable;

class Router {
    private array $routes = [];
    private array $globalMiddleware = [];

    public function addGlobalMiddleware(callable $middleware): self {
        $this->globalMiddleware[] = $middleware;
        return $this;
    }

    public function get(string $path, callable|array $handler, array $middleware = []): self {
        return $this->addRoute('GET', $path, $handler, $middleware);
    }

    public function post(string $path, callable|array $handler, array $middleware = []): self {
        return $this->addRoute('POST', $path, $handler, $middleware);
    }

    public function put(string $path, callable|array $handler, array $middleware = []): self {
        return $this->addRoute('PUT', $path, $handler, $middleware);
    }

    public function delete(string $path, callable|array $handler, array $middleware = []): self {
        return $this->addRoute('DELETE', $path, $handler, $middleware);
    }

    private function addRoute(string $method, string $path, callable|array $handler, array $middleware = []): self {
        $normalizedPath = '/' . trim($path, '/');
        // Convert {param} placeholders to regex named groups
        $pattern = preg_replace('/\{([a-zA-Z0-9_]+)\}/', '(?P<$1>[^/]+)', $normalizedPath);
        $regex = '#^' . $pattern . '$#';

        $this->routes[] = [
            'method' => $method,
            'path' => $normalizedPath,
            'regex' => $regex,
            'handler' => $handler,
            'middleware' => $middleware,
        ];

        return $this;
    }

    public function dispatch(Request $request): void {
        // Handle preflight OPTIONS request
        if ($request->getMethod() === 'OPTIONS') {
            http_response_code(204);
            header('Access-Control-Allow-Origin: *');
            header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
            header('Access-Control-Allow-Headers: Authorization, Content-Type, Accept, X-Requested-With');
            exit;
        }

        $requestPath = '/' . trim($request->getPath(), '/');
        $requestMethod = $request->getMethod();

        foreach ($this->routes as $route) {
            if ($route['method'] !== $requestMethod) {
                continue;
            }

            if (preg_match($route['regex'], $requestPath, $matches)) {
                $params = [];
                foreach ($matches as $key => $value) {
                    if (is_string($key)) {
                        $params[$key] = $value;
                    }
                }
                $request->setParams($params);

                // Run global middleware
                foreach ($this->globalMiddleware as $middleware) {
                    $result = call_user_func($middleware, $request);
                    if ($result === false) {
                        return;
                    }
                }

                // Run route middleware
                foreach ($route['middleware'] as $middleware) {
                    $result = call_user_func($middleware, $request);
                    if ($result === false) {
                        return;
                    }
                }

                // Execute handler
                try {
                    $handler = $route['handler'];
                    if (is_array($handler) && count($handler) === 2) {
                        [$class, $method] = $handler;
                        $controller = is_string($class) ? new $class() : $class;
                        $controller->$method($request);
                    } elseif (is_callable($handler)) {
                        $handler($request);
                    }
                    return;
                } catch (Throwable $e) {
                    error_log("Controller error: " . $e->getMessage() . "\n" . $e->getTraceAsString());
                    Response::error($e->getMessage(), 'SERVER_ERROR', 500);
                    return;
                }
            }
        }

        Response::error("Route {$requestMethod} {$requestPath} not found", 'NOT_FOUND', 404);
    }
}
