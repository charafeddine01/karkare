// =============================================================================
// CarLog Mandatory OTP Verification Screen
// Validates 6-digit code sent via SMTP (15-min expiry window)
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../core/network/toast_service.dart';
import '../dashboard/garage_dashboard_screen.dart';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyOtpScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _codeController = TextEditingController();
  int _secondsRemaining = 15 * 60; // 15 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 15 * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  String get _formattedTimer {
    final m = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ToastService.show('Please enter the complete 6-digit verification code', type: ToastType.warning);
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.verifyEmail(widget.email, code);

    if (!mounted) return;

    if (success) {
      ToastService.show('Email verified! Welcome to your CarLog Garage.', type: ToastType.success);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GarageDashboardScreen()),
        (route) => false,
      );
    } else {
      final err = ref.read(authProvider).errorMessage ?? 'Verification failed';
      ToastService.show(err, type: ToastType.error);
    }
  }

  Future<void> _resendCode() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final res = await apiClient.dio.post('/auth/resend-code', data: {'email': widget.email});
      if (res.statusCode == 200) {
        _startTimer();
        ToastService.show('A fresh 6-digit code has been sent to your email.', type: ToastType.success);
      }
    } catch (e) {
      ToastService.show('Failed to resend code: $e', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Verification'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CarLogTheme.surfaceDark,
                        shape: BoxShape.circle,
                        border: Border.all(color: CarLogTheme.primaryCyan),
                      ),
                      child: const Icon(Icons.mark_email_read_outlined, size: 36, color: CarLogTheme.primaryCyan),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Enter Verification Code',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CarLogTheme.textMain),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'We sent a 6-digit verification code to:\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: CarLogTheme.textMuted, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 6-digit Code Input
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 12,
                      color: CarLogTheme.primaryCyan,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        color: CarLogTheme.textMuted.withOpacity(0.3),
                      ),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Expiry Timer Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: CarLogTheme.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'Code expires in $_formattedTimer',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _secondsRemaining < 60 ? CarLogTheme.accentRed : CarLogTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Verify Button
                  ElevatedButton(
                    onPressed: authState.isLoading ? null : _verify,
                    child: authState.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: CarLogTheme.bgDark),
                          )
                        : const Text('VERIFY & ENTER GARAGE'),
                  ),
                  const SizedBox(height: 16),

                  // Resend Code
                  TextButton.icon(
                    onPressed: _resendCode,
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: CarLogTheme.primaryCyan),
                    label: const Text('Resend 6-Digit Code', style: TextStyle(color: CarLogTheme.primaryCyan, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
