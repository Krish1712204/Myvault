import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/vault_auth_notifier.dart';

class CreateVaultScreen extends ConsumerStatefulWidget {
  const CreateVaultScreen({super.key});

  @override
  ConsumerState<CreateVaultScreen> createState() => _CreateVaultScreenState();
}

class _CreateVaultScreenState extends ConsumerState<CreateVaultScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool get _hasMinLength => _passwordController.text.length >= 8;
  bool get _hasUppercase => _passwordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _passwordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasNumber => _passwordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar =>
      _passwordController.text.contains(RegExp(r'[^A-Za-z0-9\s]'));
  bool get _passwordsMatch =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateVault() async {
    FocusScope.of(context).unfocus();
    final authNotifier = ref.read(vaultAuthStateProvider.notifier);

    final success = await authNotifier.createVault(
      _passwordController.text,
      _confirmPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vault created successfully! Welcome to MyVault.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
      context.go('/');
    } else {
      final error = ref.read(vaultAuthStateProvider).errorMessage ??
          'Could not create vault. Please ensure all security requirements are satisfied.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(vaultAuthStateProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == 0 ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: index == 0 ? AppColors.primary : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        actions: const [SizedBox(width: 48)],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text(
                'Create Your Vault',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimaryNavy,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Set a strong master password to protect your data.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textMutedNavy,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Master Password Input
              Text(
                'Master Password',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !isLoading,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Enter master password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.textMutedNavy),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textMutedNavy,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Confirm Password Input
              Text(
                'Confirm Password',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                enabled: !isLoading,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Confirm master password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.textMutedNavy),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textMutedNavy,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Requirements checklist
              _buildCriteriaItem('At least 8 characters', _hasMinLength),
              _buildCriteriaItem('Include uppercase letter', _hasUppercase),
              _buildCriteriaItem('Include lowercase letter', _hasLowercase),
              _buildCriteriaItem('Include a number', _hasNumber),
              _buildCriteriaItem('Include a special character', _hasSpecialChar),
              if (_confirmPasswordController.text.isNotEmpty)
                _buildCriteriaItem('Passwords match', _passwordsMatch),
              const SizedBox(height: AppSpacing.xl),
              // Create Vault Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleCreateVault,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Create Vault',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCriteriaItem(String label, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isSatisfied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isSatisfied ? AppColors.success : AppColors.textMutedNavy,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: TextStyle(
              color: isSatisfied ? AppColors.textPrimaryNavy : AppColors.textSecondaryNavy,
              fontSize: 14,
              fontWeight: isSatisfied ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
