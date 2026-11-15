<?php
declare(strict_types=1);

namespace CarLog\Auth;

use CarLog\Config\Database;
use PDO;
use RuntimeException;
use InvalidArgumentException;

class AuthService {
    private PDO $db;
    private JwtHandler $jwt;
    private Mailer $mailer;

    public function __construct() {
        $this->db = Database::getConnection();
        $this->jwt = new JwtHandler();
        $this->mailer = new Mailer();
    }

    public function register(string $fullName, string $email, string $password): array {
        $fullName = trim($fullName);
        $email = strtolower(trim($email));

        if (empty($fullName)) {
            throw new InvalidArgumentException("Full name is required");
        }
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new InvalidArgumentException("Invalid email format");
        }
        if (strlen($password) < 6) {
            throw new InvalidArgumentException("Password must be at least 6 characters");
        }

        // Check existing user
        $stmt = $this->db->prepare("SELECT id, is_email_verified FROM users WHERE email = ? LIMIT 1");
        $stmt->execute([$email]);
        $existing = $stmt->fetch();

        if ($existing) {
            if ($existing['is_email_verified'] == 1) {
                throw new RuntimeException("An account with this email already exists");
            }
            // If exists but unverified, update OTP and resend
            $otp = (string)random_int(100000, 999999);
            $expiresAt = date('Y-m-d H:i:s', time() + 15 * 60);
            $hash = password_hash($password, PASSWORD_BCRYPT);

            $update = $this->db->prepare(
                "UPDATE users SET full_name = ?, password_hash = ?, verification_code = ?, verification_expires_at = ? WHERE id = ?"
            );
            $update->execute([$fullName, $hash, $otp, $expiresAt, $existing['id']]);
            $this->mailer->sendVerificationOtp($email, $fullName, $otp);

            return [
                'user_id' => $existing['id'],
                'email' => $email,
                'full_name' => $fullName,
                'is_email_verified' => false,
                'message' => 'Verification code sent to your email.'
            ];
        }

        $userId = $this->generateUuidV4();
        $passwordHash = password_hash($password, PASSWORD_BCRYPT);
        $otp = (string)random_int(100000, 999999);
        $expiresAt = date('Y-m-d H:i:s', time() + 15 * 60);

        $stmt = $this->db->prepare(
            "INSERT INTO users (id, email, password_hash, full_name, is_email_verified, verification_code, verification_expires_at)
             VALUES (?, ?, ?, ?, 0, ?, ?)"
        );
        $stmt->execute([$userId, $email, $passwordHash, $fullName, $otp, $expiresAt]);

        $this->mailer->sendVerificationOtp($email, $fullName, $otp);

        return [
            'user_id' => $userId,
            'email' => $email,
            'full_name' => $fullName,
            'is_email_verified' => false,
            'message' => 'Registration successful! Verification code sent to your email.'
        ];
    }

    public function verifyEmail(string $email, string $code): array {
        $email = strtolower(trim($email));
        $code = trim($code);

        $stmt = $this->db->prepare(
            "SELECT id, email, full_name, is_email_verified, verification_code, verification_expires_at 
             FROM users WHERE email = ? LIMIT 1"
        );
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if (!$user) {
            throw new RuntimeException("User account not found");
        }

        if ($user['is_email_verified'] == 1) {
            $tokens = $this->jwt->generateTokenPair($user);
            return [
                'user' => [
                    'id' => $user['id'],
                    'email' => $user['email'],
                    'full_name' => $user['full_name'],
                    'is_email_verified' => true,
                ],
                'tokens' => $tokens
            ];
        }

        if (empty($user['verification_code']) || $user['verification_code'] !== $code) {
            throw new RuntimeException("Invalid verification code");
        }

        if (strtotime($user['verification_expires_at']) < time()) {
            throw new RuntimeException("Verification code has expired. Please request a new code.");
        }

        // Mark verified
        $update = $this->db->prepare(
            "UPDATE users SET is_email_verified = 1, verification_code = NULL, verification_expires_at = NULL WHERE id = ?"
        );
        $update->execute([$user['id']]);

        $user['is_email_verified'] = 1;
        $tokens = $this->jwt->generateTokenPair($user);

        return [
            'user' => [
                'id' => $user['id'],
                'email' => $user['email'],
                'full_name' => $user['full_name'],
                'is_email_verified' => true,
            ],
            'tokens' => $tokens
        ];
    }

    public function resendCode(string $email): array {
        $email = strtolower(trim($email));
        $stmt = $this->db->prepare("SELECT id, email, full_name, is_email_verified FROM users WHERE email = ? LIMIT 1");
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if (!$user) {
            throw new RuntimeException("User not found");
        }
        if ($user['is_email_verified'] == 1) {
            throw new RuntimeException("Account is already verified. Please sign in.");
        }

        $otp = (string)random_int(100000, 999999);
        $expiresAt = date('Y-m-d H:i:s', time() + 15 * 60);

        $update = $this->db->prepare(
            "UPDATE users SET verification_code = ?, verification_expires_at = ? WHERE id = ?"
        );
        $update->execute([$otp, $expiresAt, $user['id']]);

        $this->mailer->sendVerificationOtp($email, $user['full_name'], $otp);

        return ['message' => 'New verification code has been dispatched to your email.'];
    }

    public function login(string $email, string $password): array {
        $email = strtolower(trim($email));
        $stmt = $this->db->prepare("SELECT * FROM users WHERE email = ? LIMIT 1");
        $stmt->execute([$email]);
        $user = $stmt->fetch();

        if (!$user || !password_verify($password, $user['password_hash'] ?? '')) {
            throw new RuntimeException("Invalid email or password");
        }

        if ($user['is_email_verified'] == 0) {
            throw new RuntimeException("EMAIL_NOT_VERIFIED: Please verify your email with the 6-digit code.");
        }

        $tokens = $this->jwt->generateTokenPair($user);

        return [
            'user' => [
                'id' => $user['id'],
                'email' => $user['email'],
                'full_name' => $user['full_name'],
                'is_email_verified' => true,
            ],
            'tokens' => $tokens
        ];
    }

    public function verifyGoogleToken(string $idToken): array {
        // Query Google tokeninfo endpoint
        $url = "https://oauth2.googleapis.com/tokeninfo?id_token=" . urlencode($idToken);
        
        $ch = curl_init();
        curl_setopt($ch, CURLOPT_URL, $url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_TIMEOUT, 10);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($httpCode !== 200 || !$response) {
            throw new RuntimeException("Failed to verify Google ID token");
        }

        $payload = json_decode($response, true);
        if (!isset($payload['sub']) || !isset($payload['email'])) {
            throw new RuntimeException("Invalid Google token payload");
        }

        $googleSub = $payload['sub'];
        $email = strtolower($payload['email']);
        $fullName = $payload['name'] ?? explode('@', $email)[0];

        // Check if user exists by google_sub_id or email
        $stmt = $this->db->prepare("SELECT * FROM users WHERE google_sub_id = ? OR email = ? LIMIT 1");
        $stmt->execute([$googleSub, $email]);
        $user = $stmt->fetch();

        if ($user) {
            if (empty($user['google_sub_id'])) {
                $up = $this->db->prepare("UPDATE users SET google_sub_id = ?, is_email_verified = 1 WHERE id = ?");
                $up->execute([$googleSub, $user['id']]);
            }
        } else {
            $userId = $this->generateUuidV4();
            $ins = $this->db->prepare(
                "INSERT INTO users (id, email, google_sub_id, full_name, is_email_verified) VALUES (?, ?, ?, ?, 1)"
            );
            $ins->execute([$userId, $email, $googleSub, $fullName]);
            
            $stmt = $this->db->prepare("SELECT * FROM users WHERE id = ?");
            $stmt->execute([$userId]);
            $user = $stmt->fetch();
        }

        $tokens = $this->jwt->generateTokenPair($user);

        return [
            'user' => [
                'id' => $user['id'],
                'email' => $user['email'],
                'full_name' => $user['full_name'],
                'is_email_verified' => true,
            ],
            'tokens' => $tokens
        ];
    }

    public function refreshToken(string $refreshToken): array {
        $decoded = $this->jwt->decode($refreshToken);
        if (($decoded['type'] ?? '') !== 'refresh') {
            throw new RuntimeException("Invalid refresh token type");
        }

        $userId = $decoded['sub'];
        $stmt = $this->db->prepare("SELECT * FROM users WHERE id = ? LIMIT 1");
        $stmt->execute([$userId]);
        $user = $stmt->fetch();

        if (!$user) {
            throw new RuntimeException("User not found");
        }

        return $this->jwt->generateTokenPair($user);
    }

    private function generateUuidV4(): string {
        $data = random_bytes(16);
        $data[6] = chr(ord($data[6]) & 0x0f | 0x40); // set version to 0100
        $data[8] = chr(ord($data[8]) & 0x3f | 0x80); // set bits 6-7 to 10
        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }
}
