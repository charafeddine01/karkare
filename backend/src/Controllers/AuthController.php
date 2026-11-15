<?php
declare(strict_types=1);

namespace CarLog\Controllers;

use CarLog\Auth\AuthService;
use CarLog\Router\Request;
use CarLog\Router\Response;
use Throwable;

class AuthController {
    private AuthService $auth;

    public function __construct() {
        $this->auth = new AuthService();
    }

    public function register(Request $request): void {
        $fullName = (string)$request->get('full_name', '');
        $email = (string)$request->get('email', '');
        $password = (string)$request->get('password', '');

        try {
            $result = $this->auth->register($fullName, $email, $password);
            Response::success($result, 'Registration submitted. Please check email for verification code.', 201);
        } catch (Throwable $e) {
            Response::error($e->getMessage(), 'REGISTRATION_FAILED', 400);
        }
    }

    public function verifyEmail(Request $request): void {
        $email = (string)$request->get('email', '');
        $code = (string)$request->get('code', '');

        try {
            $result = $this->auth->verifyEmail($email, $code);
            Response::success($result, 'Email verified successfully.');
        } catch (Throwable $e) {
            Response::error($e->getMessage(), 'VERIFICATION_FAILED', 400);
        }
    }

    public function resendCode(Request $request): void {
        $email = (string)$request->get('email', '');

        try {
            $result = $this->auth->resendCode($email);
            Response::success($result, 'Verification code resent.');
        } catch (Throwable $e) {
            Response::error($e->getMessage(), 'RESEND_FAILED', 400);
        }
    }

    public function login(Request $request): void {
        $email = (string)$request->get('email', '');
        $password = (string)$request->get('password', '');

        try {
            $result = $this->auth->login($email, $password);
            Response::success($result, 'Login successful.');
        } catch (Throwable $e) {
            $message = $e->getMessage();
            $code = str_contains($message, 'EMAIL_NOT_VERIFIED') ? 'EMAIL_NOT_VERIFIED' : 'LOGIN_FAILED';
            Response::error($message, $code, 401);
        }
    }

    public function googleSignIn(Request $request): void {
        $idToken = (string)$request->get('id_token', '');
        if (empty($idToken)) {
            Response::error('Google ID token is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $result = $this->auth->verifyGoogleToken($idToken);
            Response::success($result, 'Google authentication successful.');
        } catch (Throwable $e) {
            Response::error($e->getMessage(), 'GOOGLE_AUTH_FAILED', 401);
        }
    }

    public function refresh(Request $request): void {
        $refreshToken = (string)$request->get('refresh_token', '');
        if (empty($refreshToken)) {
            Response::error('Refresh token is required', 'VALIDATION_ERROR', 400);
            return;
        }

        try {
            $result = $this->auth->refreshToken($refreshToken);
            Response::success($result, 'Token refreshed.');
        } catch (Throwable $e) {
            Response::error($e->getMessage(), 'REFRESH_FAILED', 401);
        }
    }

    public function me(Request $request): void {
        $user = $request->getUser();
        Response::success($user, 'User profile retrieved.');
    }
}
