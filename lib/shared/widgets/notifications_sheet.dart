import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../state/vault_insights_provider.dart';

/// Security alerts computed from the vault itself (backup age, weak and reused passwords).
/// Alerts can be cleared one by one (swipe or ×) or all at once; a cleared alert returns
/// only if its underlying condition changes.
class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
            // Above the bottom navigation bar, not inside the current tab.
      useRootNavigator: true,
context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(visibleAlertsProvider);
    final alerts = alertsAsync.valueOrNull ?? const <VaultAlert>[];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = AppColors.sheetSurface;
    final textPrimary = AppColors.textPrimaryNavy;

    void dismiss(Iterable<String> ids) {
      HapticFeedback.lightImpact();
      ref.read(alertDismissalsProvider.notifier).dismiss(ids);
    }

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security Alerts',
                        style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                      Text(
                        alerts.isEmpty ? 'All clear' : '${alerts.length} need${alerts.length == 1 ? 's' : ''} attention',
                        style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: alerts.isEmpty
                      ? const SizedBox.shrink()
                      : TextButton.icon(
                          key: const ValueKey('clear-all'),
                          onPressed: () => dismiss(alerts.map((a) => a.id)),
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: const Text('Clear all', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: alertsAsync.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: alerts.isEmpty
                          ? _AllClear(isDark: isDark, textPrimary: textPrimary)
                          : ListView.separated(
                              key: const ValueKey('alerts'),
                              shrinkWrap: true,
                              itemCount: alerts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final alert = alerts[i];
                                return Dismissible(
                                  key: ValueKey(alert.id),
                                  direction: DismissDirection.horizontal,
                                  onDismissed: (_) => dismiss([alert.id]),
                                  background: const _SwipeHint(alignment: Alignment.centerLeft),
                                  secondaryBackground: const _SwipeHint(alignment: Alignment.centerRight),
                                  child: _AlertTile(
                                    alert: alert,
                                    isDark: isDark,
                                    textPrimary: textPrimary,
                                    onDismiss: () => dismiss([alert.id]),
                                    onAction: alert.actionRoute == null
                                        ? null
                                        : () {
                                            Navigator.pop(context);
                                            context.push(alert.actionRoute!);
                                          },
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllClear extends StatelessWidget {
  final bool isDark;
  final Color textPrimary;

  const _AllClear({required this.isDark, required this.textPrimary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('clear'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(isDark ? 45 : 30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 36),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "You're all caught up",
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'No security alerts right now.',
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  final Alignment alignment;

  const _SwipeHint({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(30),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_rounded, color: AppColors.success, size: 18),
          SizedBox(width: 6),
          Text('Clear', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final VaultAlert alert;
  final bool isDark;
  final Color textPrimary;
  final VoidCallback onDismiss;
  final VoidCallback? onAction;

  const _AlertTile({
    required this.alert,
    required this.isDark,
    required this.textPrimary,
    required this.onDismiss,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final critical = alert.level == VaultAlertLevel.critical;
    final color = critical ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(isDark ? 80 : 50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withAlpha(isDark ? 50 : 30), borderRadius: BorderRadius.circular(12)),
            child: Icon(
              critical ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: TextStyle(color: textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  alert.description,
                  style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, height: 1.4),
                ),
                if (alert.actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: onAction,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            alert.actionLabel!,
                            style: const TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 15),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textMutedNavy),
          ),
        ],
      ),
    );
  }
}
