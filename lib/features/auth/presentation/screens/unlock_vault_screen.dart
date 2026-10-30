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
  @override
  void initState() {
    super.initState();
    // Auto-prompt fingerprint scanner as soon as screen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleBiometricUnlock();
    });
  }

  Future<void> _handleBiometricUnlock() async {
    final authState = ref.read(vaultAuthStateProvider);
    final authNotifier = ref.read(vaultAuthStateProvider.notifier);

    if (!authState.isBiometricAvailable || !authState.isBiometricEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Biometric fingerprint is not enabled or not enrolled on this device.',
            ),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final success = await authNotifier.unlockWithBiometrics();
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vault unlocked successfully!'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 1),
        ),
      );
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(vaultAuthStateProvider);
    final canUseBiometrics = authState.isBiometricAvailable && authState.isBiometricEnabled;

    String biometricStatusHint;
    if (canUseBiometrics) {
      biometricStatusHint = 'Touch the fingerprint sensor to unlock';
    } else if (!authState.isBiometricAvailable) {
      biometricStatusHint = 'Biometrics not enrolled on device';
    } else {
      biometricStatusHint = 'Biometric unlock is disabled in Settings';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimaryNavy, size: 20),
          onPressed: () => context.go('/welcome'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              const VaultShieldLogo(size: 80),
              const SizedBox(height: AppSpacing.md),
              Text(
                'MyVault',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
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

              // Biometric sensor graphic (Tap to trigger fingerprint)
              InkWell(
                onTap: _handleBiometricUnlock,
                borderRadius: BorderRadius.circular(50),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: BiometricSensorWidget(
                    onTap: _handleBiometricUnlock,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                'Fingerprint Security',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimaryNavy,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                canUseBiometrics
                    ? 'Use your fingerprint to open your vault\ninstantly and securely.'
                    : 'Please enroll fingerprint in phone settings to proceed.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMutedNavy,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  biometricStatusHint,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),

              // Primary "Scan Fingerprint" Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleBiometricUnlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.fingerprint_rounded, size: 24),
                  label: const Text(
                    'Scan Fingerprint',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Back to Welcome Screen
              TextButton(
                onPressed: () => context.go('/welcome'),
                child: const Text(
                  'Back to Welcome',
                  style: TextStyle(
                    color: AppColors.textMutedNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
