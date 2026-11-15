<?php
declare(strict_types=1);

namespace CarLog\Auth;

use CarLog\Config\Config;
use Throwable;

class Mailer {
    private array $config;

    public function __construct() {
        $this->config = Config::get()['smtp'];
    }

    public function sendVerificationOtp(string $recipientEmail, string $recipientName, string $otpCode): bool {
        $subject = "Your CarLog Verification Code: {$otpCode}";
        
        $htmlBody = <<<HTML
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>CarLog Email Verification</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #0F172A; margin: 0; padding: 24px; color: #E2E8F0; }
        .container { max-width: 520px; margin: 0 auto; background: #1E293B; border-radius: 12px; border: 1px solid #334155; padding: 32px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
        .logo { font-size: 24px; font-weight: 800; color: #38BDF8; letter-spacing: 1px; margin-bottom: 24px; }
        .badge { display: inline-block; padding: 4px 10px; background: rgba(56, 189, 248, 0.15); border: 1px solid #38BDF8; border-radius: 20px; font-size: 12px; font-weight: 600; color: #38BDF8; margin-bottom: 16px; }
        h1 { font-size: 20px; color: #F8FAFC; margin-bottom: 12px; }
        p { font-size: 14px; line-height: 1.6; color: #94A3B8; margin-bottom: 24px; }
        .otp-box { background: #0F172A; border: 2px dashed #0284C7; border-radius: 10px; padding: 18px; text-align: center; margin: 24px 0; }
        .otp-code { font-size: 34px; font-weight: 800; letter-spacing: 8px; color: #38BDF8; font-family: 'Courier New', Courier, monospace; }
        .footer { font-size: 12px; color: #64748B; text-align: center; margin-top: 32px; border-top: 1px solid #334155; padding-top: 16px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">⚡ CARLOG GARAGE</div>
        <div class="badge">SECURITY VERIFICATION</div>
        <h1>Welcome, {$recipientName}!</h1>
        <p>Thank you for registering on CarLog, your offline-first vehicle and motorcycle maintenance platform. Please enter the 6-digit verification code below to activate your account:</p>
        
        <div class="otp-box">
            <div class="otp-code">{$otpCode}</div>
        </div>
        
        <p>This code will expire in <strong>15 minutes</strong>. If you did not create a CarLog account, you can safely ignore this email.</p>
        
        <div class="footer">
            &copy; CarLog Platform &bull; Offline-First Garage Engine &bull; Strictly Metric & USD
        </div>
    </div>
</body>
</html>
HTML;

        // If PHPMailer class is available, use it
        if (class_exists('\PHPMailer\PHPMailer\PHPMailer')) {
            try {
                $mail = new \PHPMailer\PHPMailer\PHPMailer(true);
                $mail->isSMTP();
                $mail->Host       = $this->config['host'];
                $mail->SMTPAuth   = true;
                $mail->Username   = $this->config['username'];
                $mail->Password   = $this->config['password'];
                $mail->SMTPSecure = $this->config['encryption'] === 'ssl' ? \PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_SMTPS : \PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_STARTTLS;
                $mail->Port       = $this->config['port'];

                $mail->setFrom($this->config['from_email'], $this->config['from_name']);
                $mail->addAddress($recipientEmail, $recipientName);
                $mail->isHTML(true);
                $mail->Subject = $subject;
                $mail->Body    = $htmlBody;
                $mail->AltBody = "Your CarLog verification code is: {$otpCode}. Expires in 15 minutes.";

                return $mail->send();
            } catch (Throwable $e) {
                error_log("PHPMailer error: " . $e->getMessage());
            }
        }

        // Native PHP mail() / SMTP fallback
        return $this->nativeSend($recipientEmail, $subject, $htmlBody);
    }

    private function nativeSend(string $to, string $subject, string $htmlBody): bool {
        $headers = [
            'MIME-Version: 1.0',
            'Content-type: text/html; charset=utf-8',
            "From: {$this->config['from_name']} <{$this->config['from_email']}>",
            "Reply-To: {$this->config['from_email']}",
            'X-Mailer: CarLog-Native-Mailer/1.0',
        ];

        try {
            return @mail($to, $subject, $htmlBody, implode("\r\n", $headers));
        } catch (Throwable $e) {
            error_log("Native mail error: " . $e->getMessage());
            return false;
        }
    }
}
