// =============================================================================
// CarLog Toast & Reason Notification Service
// Global messenger key with automotive dark-mode styled notifications
// =============================================================================

import 'package:flutter/material.dart';

enum ToastType { info, success, warning, error }

class ToastService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void show(
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final state = messengerKey.currentState;
    if (state == null) return;

    Color bg;
    Color border;
    IconData icon;

    switch (type) {
      case ToastType.success:
        bg = const Color(0xFF064E3B);
        border = const Color(0xFF10B981);
        icon = Icons.check_circle_outline;
        break;
      case ToastType.warning:
        bg = const Color(0xFF78350F);
        border = const Color(0xFFF59E0B);
        icon = Icons.warning_amber_rounded;
        break;
      case ToastType.error:
        bg = const Color(0xFF7F1D1D);
        border = const Color(0xFFEF4444);
        icon = Icons.error_outline;
        break;
      case ToastType.info:
      default:
        bg = const Color(0xFF1E293B);
        border = const Color(0xFF38BDF8);
        icon = Icons.info_outline;
        break;
    }

    state.removeCurrentSnackBar();
    state.showSnackBar(
      SnackBar(
        elevation: 8,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border, width: 1.5),
        ),
        duration: duration,
        content: Row(
          children: [
            Icon(icon, color: border, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: border,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }
}
