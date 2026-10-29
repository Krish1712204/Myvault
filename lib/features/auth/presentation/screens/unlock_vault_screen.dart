import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/vault_auth_notifier.dart';
import '../widgets/biometric_sensor_widget.dart';
import '../widgets/vault_shield_logo.dart';

class UnlockVaultScreen extends ConsumerStatefulWidget {
  const UnlockVaultScreen({super.key});

  @override
  ConsumerState<UnlockVaultScreen> createState() => _UnlockVaultScreenState();
}

class _UnlockVaultScreenState extends ConsumerState<UnlockVaultScreen> {
  Future<void> _handleBiometricUnlock() async {
    final authState = ref.read(vaultAuthStateProvider);
    final authNotifier = ref.read(vaultAuthStateProvider.notifier);

    if (!authState.isBiometricAvailable || !authState.isBiometricEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometric unlock is not enabled or not supported on this device. Please enter your master password.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final success = await authNotifier.unlockWithBiometrics();
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vault unlocked successfully!'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
      context.go('/');
    }
  }

  void _showPasswordDialog() {
    final passwordController = TextEditingController();
    bool obscure = true;
    String? dialogError;
    bool isAuthenticating = false;

    showDialog(
      context: context,
      barrierDismissible: !isAuthenticating,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Enter Master Password',
              style: TextStyle(
                color: AppColors.textPrimaryNavy,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  autofocus: true,
                  enabled: !isAuthenticating,
                  onSubmitted: (_) async {
                    if (isAuthenticating) return;
                    setDialogState(() {
                      isAuthenticating = true;
                      dialogError = null;
                    });
                    final success = await ref
                        .read(vaultAuthStateProvider.notifier)
                        .unlockWithPassword(passwordController.text);
                    if (!ctx.mounted) return;
                    if (success) {
                      Navigator.pop(ctx);
                      if (mounted) {
                        context.go('/');
                      }
                    } else {
                      setDialogState(() {
                        isAuthenticating = false;
                        dialogError = 'Incorrect master password. Please try again.';
                      });
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Master password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMutedNavy),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.textMutedNavy,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscure = !obscure;
                        });
                      },
                    ),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isAuthenticating ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isAuthenticating
                    ? null
                    : () async {
                        setDialogState(() {
                          isAuthenticating = true;
                          dialogError = null;
                        });

                        final success = await ref
                            .read(vaultAuthStateProvider.notifier)
                            .unlockWithPassword(passwordController.text);

                        if (!ctx.mounted) return;

                        if (success) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Vault unlocked successfully!'),
                                backgroundColor: AppColors.primary,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            context.go('/');
                          }
                        } else {
                          setDialogState(() {
                            isAuthenticating = false;
                            dialogError = 'Incorrect master password. Please try again.';
                          });
                        }
                      },
                child: isAuthenticating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Unlock'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showZeroKnowledgeInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primary, size: 24),
            SizedBox(width: 8),
            Text(
              'Zero-Knowledge Security',
              style: TextStyle(
                color: AppColors.textPrimaryNavy,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: const Text(
          'MyVault operates with strict zero-knowledge architecture. '
          'Your Master Password is never stored in plaintext and never transmitted anywhere.\n\n'
          'Because of this encryption model, there is no remote password reset or backdoor recovery mechanism. '
          'Without your master password, your vault data cannot be recovered.',
          style: TextStyle(
            color: AppColors.textSecondaryNavy,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(vaultAuthStateProvider);
    final canUseBiometrics = authState.isBiometricAvailable && authState.isBiometricEnabled;

    String biometricStatusHint;
    if (canUseBiometrics) {
      biometricStatusHint = 'Touch the fingerprint sensor';
    } else if (!authState.isBiometricAvailable) {
      biometricStatusHint = 'Biometrics not enrolled on device';
    } else {
      biometricStatusHint = 'Biometric unlock is disabled in Settings';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xl),
              const VaultShieldLogo(size: 80),
              const SizedBox(height: AppSpacing.md),
              Text(
                'MyVault',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 28,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your Personal Digital Vault',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textMutedNavy,
                    ),
              ),
              const Spacer(),
              // Biometric sensor graphic
              Opacity(
                opacity: canUseBiometrics ? 1.0 : 0.45,
                child: BiometricSensorWidget(
                  onTap: _handleBiometricUnlock,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Unlock with Fingerprint',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimaryNavy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                canUseBiometrics
                    ? 'Use your fingerprint to open your vault\nquickly and securely.'
                    : 'Biometrics unavailable. Use your master password below.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMutedNavy,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                biometricStatusHint,
                style: TextStyle(
                  color: canUseBiometrics ? AppColors.primary : AppColors.textMutedNavy,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              // "OR" Divider
              const Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: AppColors.textMutedNavy,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Enter Master Password Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showPasswordDialog,
                  icon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                  label: const Text(
                    'Enter Master Password',
                    style: TextStyle(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _showZeroKnowledgeInfo,
                child: const Text(
                  'Forgot your password?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
