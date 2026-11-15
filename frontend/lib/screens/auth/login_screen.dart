// =============================================================================
// CarLog Login Screen
// Email & Password Auth + Google Sign-In + Mandatory OTP Verification Redirection
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../core/network/toast_service.dart';
import 'register_screen.dart';
import 'verify_otp_screen.dart';
import '../dashboard/garage_dashboard_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final authNotifier = ref.read(authProvider.notifier);
    final success = await authNotifier.login(email, password);

    if (!mounted) return;

    if (success) {
      ToastService.show('Welcome back to CarLog Garage!', type: ToastType.success);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GarageDashboardScreen()),
      );
    } else {
      final err = ref.read(authProvider).errorMessage ?? 'Login failed';
      if (err.contains('EMAIL_NOT_VERIFIED')) {
        ToastService.show('Account unverified. Please enter your 6-digit OTP code.', type: ToastType.warning);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VerifyOtpScreen(email: email)),
        );
      } else {
        ToastService.show(err, type: ToastType.error);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        ToastService.show('Failed to obtain Google ID token', type: ToastType.error);
        return;
      }

      final success = await ref.read(authProvider.notifier).googleSignIn(idToken);
      if (!mounted) return;

      if (success) {
        ToastService.show('Google Sign-In successful!', type: ToastType.success);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GarageDashboardScreen()),
        );
      } else {
        final err = ref.read(authProvider).errorMessage ?? 'Google authentication failed';
        ToastService.show(err, type: ToastType.error);
      }
    } catch (e) {
      ToastService.show('Google Sign-In error: $e', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Logo & Heading
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CarLogTheme.surfaceDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: CarLogTheme.primaryCyan, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: CarLogTheme.primaryCyan.withOpacity(0.2),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.directions_car_filled_rounded, size: 40, color: CarLogTheme.primaryCyan),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'CARLOG GARAGE',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: CarLogTheme.textMain,
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'Offline-First Vehicle & Motorcycle Maintenance',
                        style: TextStyle(fontSize: 12.5, color: CarLogTheme.textMuted),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined, color: CarLogTheme.primaryCyan, size: 20),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty || !val.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: CarLogTheme.primaryCyan, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: CarLogTheme.textMuted,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Login Button
                    ElevatedButton(
                      onPressed: authState.isLoading ? null : _handleLogin,
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: CarLogTheme.bgDark),
                            )
                          : const Text('SIGN IN TO GARAGE'),
                    ),
                    const SizedBox(height: 16),

                    // Google Sign-In
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: CarLogTheme.borderDark),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28, color: CarLogTheme.textMain),
                      label: const Text('Sign In with Google', style: TextStyle(color: CarLogTheme.textMain, fontWeight: FontWeight.w600)),
                      onPressed: authState.isLoading ? null : _handleGoogleSignIn,
                    ),
                    const SizedBox(height: 24),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have a garage account?", style: TextStyle(fontSize: 13, color: CarLogTheme.textMuted)),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold, color: CarLogTheme.primaryCyan)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
