import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../widgets/biometric_sensor_widget.dart';
import '../widgets/vault_shield_logo.dart';

class UnlockVaultScreen extends ConsumerWidget {
  const UnlockVaultScreen({super.key});

  void _unlock(BuildContext context, WidgetRef ref) {
    ref.read(authStateProvider.notifier).unlockVault();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vault unlocked successfully!'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );
    context.go('/');
  }

  void _showPasswordDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Master Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Master password',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unlock(context, ref);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              BiometricSensorWidget(
                onTap: () => _unlock(context, ref),
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
                'Use your fingerprint to open your vault\nquickly and securely.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMutedNavy,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                'Touch the fingerprint sensor',
                style: TextStyle(
                  color: AppColors.primary,
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
                  onPressed: () => _showPasswordDialog(context, ref),
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recovery options are accessible via Master Key in future phases.'),
                    ),
                  );
                },
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
