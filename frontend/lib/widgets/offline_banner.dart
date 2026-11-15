// =============================================================================
// CarLog Persistent Offline Banner & Sync Status Pill
// Displays offline indicator and pending local sync changes badge
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/carlog_providers.dart';
import '../core/theme/carlog_theme.dart';
import '../core/network/toast_service.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnlineAsync = ref.watch(networkConnectivityProvider);
    final pendingCountAsync = ref.watch(pendingSyncCountProvider);

    final isOnline = isOnlineAsync.value ?? true;
    final pendingCount = pendingCountAsync.value ?? 0;

    if (isOnline && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: !isOnline ? const Color(0xFF78350F) : const Color(0xFF1E293B),
        border: Border(
          bottom: BorderSide(
            color: !isOnline ? CarLogTheme.accentAmber : CarLogTheme.borderDark,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            !isOnline ? Icons.cloud_off_rounded : Icons.sync_rounded,
            size: 18,
            color: !isOnline ? CarLogTheme.accentAmber : CarLogTheme.primaryCyan,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              !isOnline
                  ? 'Offline Mode — Changes saved locally'
                  : 'Sync Ready ($pendingCount changes pending upload)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: !isOnline ? const Color(0xFFFEF3C7) : CarLogTheme.textMain,
              ),
            ),
          ),
          if (pendingCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: CarLogTheme.primaryDarkCyan,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$pendingCount',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (isOnline)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final engine = ref.read(syncEngineProvider);
                ToastService.show('Syncing with remote garage...', type: ToastType.info);
                final res = await engine.synchronize();
                if (res.success) {
                  ref.invalidate(pendingSyncCountProvider);
                  ref.invalidate(vehiclesStreamProvider);
                  ToastService.show(
                    'Sync complete (+${res.pushedCount} pushed, +${res.pulledCount} pulled)',
                    type: ToastType.success,
                  );
                } else {
                  ToastService.show(res.errorMessage ?? 'Sync failed', type: ToastType.error);
                }
              },
              child: const Text(
                'Sync Now',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: CarLogTheme.primaryCyan),
              ),
            ),
        ],
      ),
    );
  }
}
