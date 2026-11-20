import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/ui/motion.dart';
import '../../../auth/domain/vault_auth_notifier.dart';
import '../../../vault_items/presentation/widgets/password_generator_sheet.dart';

class _Tip {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String action;
  final void Function(BuildContext context) onAction;

  const _Tip(this.icon, this.color, this.title, this.body, this.action, this.onAction);
}

/// A rotating strip of short, accurate tips, each with a one-tap action.
/// Tips that no longer apply (e.g. fingerprint already on) are left out.
class VaultTipsCard extends ConsumerStatefulWidget {
  const VaultTipsCard({super.key});

  @override
  ConsumerState<VaultTipsCard> createState() => _VaultTipsCardState();
}

class _VaultTipsCardState extends ConsumerState<VaultTipsCard> {
  Timer? _timer;
  int _index = DateTime.now().day; // a different first tip each day

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (motionEnabled(context)) {
      _timer = Timer.periodic(const Duration(seconds: 7), (_) {
        if (mounted) setState(() => _index++);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<_Tip> _tips(bool fingerprintOn) => [
        if (!fingerprintOn)
          _Tip(Icons.fingerprint_rounded, const Color(0xFF6366F1), 'Unlock in a touch',
              'Turn on fingerprint unlock in Settings.', 'Turn on', (c) => c.go('/settings')),
        _Tip(Icons.cloud_upload_rounded, const Color(0xFF8B5CF6), 'Back up your vault',
            'A backup is the only way to recover if this phone is lost.', 'Back up', (c) => c.push('/backup-restore')),
        _Tip(Icons.password_rounded, AppColors.success, 'One password per account',
            'Generate a unique, strong password for every login.', 'Generate', (c) => PasswordGeneratorSheet.show(c)),
        _Tip(Icons.format_bold_rounded, AppColors.categoryNotes, 'Highlight what matters',
            'Select words in a note and tap Bold.', 'New note', (c) => c.push('/add-note')),
        _Tip(Icons.lock_clock_rounded, AppColors.primary, 'It locks itself',
            'Your vault locks when you leave the app or stop using it.', 'Settings', (c) => c.go('/settings')),
      ];

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(vaultAuthStateProvider);
    final tips = _tips(auth.isBiometricAvailable && auth.isBiometricEnabled);
    final tip = tips[_index % tips.length];

    return GestureDetector(
      onHorizontalDragEnd: (d) => setState(() => _index += (d.primaryVelocity ?? 0) < 0 ? 1 : tips.length - 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tip.color.withAlpha(60)),
          gradient: LinearGradient(
            colors: [tip.color.withAlpha(AppColors.isDark ? 40 : 22), AppColors.surface],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: Row(
            key: ValueKey(tip.title),
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: tip.color.withAlpha(36), borderRadius: BorderRadius.circular(12)),
                child: Icon(tip.icon, color: tip.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'TIP',
                          style: TextStyle(color: tip.color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            tip.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 13.5, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tip.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => tip.onAction(context),
                style: TextButton.styleFrom(foregroundColor: tip.color, visualDensity: VisualDensity.compact),
                child: Text(tip.action, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
