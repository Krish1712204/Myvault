import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/profile/user_profile_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/ui/motion.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../domain/vault_auth_notifier.dart';
import '../widgets/aurora_background.dart';
import '../widgets/fingerprint_scanner.dart';
import '../widgets/vault_shield_logo.dart';

class UnlockVaultScreen extends ConsumerStatefulWidget {
  const UnlockVaultScreen({super.key});

  @override
  ConsumerState<UnlockVaultScreen> createState() => _UnlockVaultScreenState();
}

class _UnlockVaultScreenState extends ConsumerState<UnlockVaultScreen> {
  ScannerPhase _phase = ScannerPhase.idle;
  static const _successHold = Duration(milliseconds: 950);

  @override
  void initState() {
    super.initState();
    // Prompt straight away: fingerprint if set up, otherwise the master password.
    WidgetsBinding.instance.addPostFrameCallback((_) => _primaryAction());
  }

  bool get _canUseBiometrics {
    final auth = ref.read(vaultAuthStateProvider);
    return auth.isBiometricAvailable && auth.isBiometricEnabled;
  }

  Future<void> _primaryAction() => _canUseBiometrics ? _unlockWithFingerprint() : _showPasswordSheet();

  Future<void> _playSuccess() async {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _phase = ScannerPhase.success);
    await Future.delayed(_successHold);
  }

  Future<void> _unlockWithFingerprint() async {
    if (_phase == ScannerPhase.scanning || _phase == ScannerPhase.success) return;
    final notifier = ref.read(vaultAuthStateProvider.notifier);
    notifier.clearError();
    setState(() => _phase = ScannerPhase.scanning);

    final success = await notifier.unlockWithBiometrics(onVerified: _playSuccess);
    if (!mounted) return;
    if (success) {
      context.go('/');
      return;
    }

    if (ref.read(vaultAuthStateProvider).errorMessage != null) {
      HapticFeedback.heavyImpact();
      setState(() => _phase = ScannerPhase.error);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
    }
    setState(() => _phase = ScannerPhase.idle);
  }

  Future<void> _showPasswordSheet() async {
    if (!mounted) return;
    final result = await showModalBottomSheet<String>(
            // Above the bottom navigation bar, not inside the current tab.
      useRootNavigator: true,
context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PasswordSheet(onVerified: _playSuccess),
    );
    if (!mounted) return;
    if (ref.read(vaultAuthStateProvider).isUnlocked) {
      context.go('/');
    } else if (result == _PasswordSheet.forgotResult) {
      await _showForgotPasswordDialog();
    }
  }

  /// The master password cannot be recovered (nothing on the device can decrypt the vault
  /// without it), so the only way forward is to erase this vault and start again, then
  /// restore a backup if there is one.
  Future<void> _showForgotPasswordDialog() async {
    final confirmController = TextEditingController();
    final erase = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Forgot master password?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your master password is the only key to this vault. It is never stored or sent '
                  'anywhere, so it cannot be reset or recovered.\n\n'
                  'You can erase this vault and create a new one. Everything in it is permanently '
                  'deleted from this phone. If you have a backup (a .myvault file or Google Drive), '
                  'you can restore it into the new vault with its backup passphrase.',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 16),
                const Text('Type ERASE to confirm', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'ERASE'),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: confirmController.text.trim() == 'ERASE'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Erase Vault'),
            ),
          ],
        ),
      ),
    );
    confirmController.dispose();
    if (erase != true || !mounted) return;

    await ref.read(vaultAuthStateProvider.notifier).eraseVault();
    // Settings kept in memory belong to the erased vault.
    ref.invalidate(userProfileProvider);
    ref.invalidate(themeModeProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vault erased. Create a new vault to continue.')),
    );
    context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(vaultAuthStateProvider);
    final profile = ref.watch(userProfileProvider);
    final canUseBiometrics = auth.isBiometricAvailable && auth.isBiometricEnabled;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryNavy;
    final animate = motionEnabled(context);

    final (statusTitle, statusBody) = switch (_phase) {
      ScannerPhase.scanning => ('Scanning…', 'Hold your finger on the sensor'),
      ScannerPhase.success => ('Unlocked', 'Opening your vault'),
      ScannerPhase.error => ("Couldn't unlock", auth.errorMessage ?? 'Try again or use your master password'),
      ScannerPhase.idle => canUseBiometrics
          ? ('Touch to unlock', 'Use the fingerprint you set up for MyVault')
          : ('Master password', 'Fingerprint unlock is off. Unlock with your password.'),
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AuroraBackground(
          animate: animate,
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scannerSize = math.min(constraints.maxWidth * 0.78, constraints.maxHeight * 0.4);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: PressableScale(
                          onTap: () => context.go('/welcome'),
                          child: Container(
                            margin: const EdgeInsets.only(top: 8),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface.withAlpha(210),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const VaultShieldLogo(size: 60),
                      const SizedBox(height: 14),
                      Text(
                        profile.hasName ? 'Welcome back, ${profile.firstName}' : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textPrimary, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: AppColors.textMutedNavy),
                          const SizedBox(width: 5),
                          Text(
                            'Your vault is locked',
                            style: TextStyle(color: AppColors.textMutedNavy, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Spacer(),
                      FingerprintScanner(
                        size: scannerSize,
                        phase: _phase,
                        animate: animate,
                        onTap: canUseBiometrics ? _unlockWithFingerprint : _showPasswordSheet,
                      ),
                      const SizedBox(height: 18),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Column(
                          key: ValueKey('$_phase$statusBody'),
                          children: [
                            Text(
                              statusTitle,
                              style: TextStyle(
                                color: switch (_phase) {
                                  ScannerPhase.success => AppColors.success,
                                  ScannerPhase.error => AppColors.error,
                                  _ => textPrimary,
                                },
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statusBody,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13.5, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      if (auth.offerBiometricSetup && _phase == ScannerPhase.idle) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(isDark ? 40 : 20),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'Fingerprint unlock was upgraded for stronger security. Unlock with your '
                            'master password once and you can turn it back on.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.4),
                          ),
                        ),
                      ],
                      const Spacer(),
                      GradientButton(
                        label: canUseBiometrics ? 'Scan Fingerprint' : 'Unlock with Master Password',
                        icon: canUseBiometrics ? Icons.fingerprint_rounded : Icons.password_rounded,
                        loading: _phase == ScannerPhase.scanning,
                        onPressed: _phase == ScannerPhase.success ? null : _primaryAction,
                      ),
                      SizedBox(
                        height: 52,
                        child: canUseBiometrics
                            ? TextButton(
                                onPressed: _phase == ScannerPhase.idle || _phase == ScannerPhase.error
                                    ? _showPasswordSheet
                                    : null,
                                child: const Text('Use master password instead', style: TextStyle(fontWeight: FontWeight.w700)),
                              )
                            : null,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with a single master-password field, inline errors, and a shake on failure.
class _PasswordSheet extends ConsumerStatefulWidget {
  /// Returned by the sheet when the user taps "Forgot master password?".
  static const forgotResult = 'forgot';

  final Future<void> Function() onVerified;

  const _PasswordSheet({required this.onVerified});

  @override
  ConsumerState<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends ConsumerState<_PasswordSheet> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final notifier = ref.read(vaultAuthStateProvider.notifier);
    final ok = await notifier.unlockWithPassword(
      _controller.text,
      onVerified: () async {
        if (mounted) Navigator.pop(context);
        await widget.onVerified();
      },
    );
    if (ok || !mounted) return;
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    setState(() {
      _busy = false;
      _error = ref.read(vaultAuthStateProvider).errorMessage ?? 'Incorrect master password.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryNavy;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        decoration: BoxDecoration(
          color: AppColors.sheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
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
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(isDark ? 50 : 24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.password_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Master password', style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('Enter it to open your vault', style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: _shake,
                builder: (context, child) => Transform.translate(
                  offset: Offset(math.sin(_shake.value * math.pi * 5) * 10 * (1 - _shake.value), 0),
                  child: child,
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: _obscure,
                  enabled: !_busy,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Master password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    errorText: _error,
                    errorMaxLines: 3,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              GradientButton(
                label: 'Unlock',
                icon: Icons.lock_open_rounded,
                loading: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, _PasswordSheet.forgotResult),
                  child: const Text('Forgot master password?', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
