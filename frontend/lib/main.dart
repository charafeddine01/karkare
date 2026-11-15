// =============================================================================
// CarLog Main Entry Point
// Platform: Offline-First Vehicle & Motorcycle Maintenance Platform
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/carlog_theme.dart';
import 'core/network/toast_service.dart';
import 'providers/carlog_providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/garage_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: CarLogApp(),
    ),
  );
}

class CarLogApp extends ConsumerWidget {
  const CarLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'CarLog Garage',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: ToastService.messengerKey,
      theme: CarLogTheme.darkTheme,
      home: authState.isAuthenticated && authState.isEmailVerified
          ? const GarageDashboardScreen()
          : const LoginScreen(),
    );
  }
}
