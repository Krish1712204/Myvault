import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../auth/domain/vault_auth_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _appLock = true;
  bool _notifications = true;
  String _selectedTheme = 'Light';

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Change Master Password',
              style: TextStyle(
                color: AppColors.textPrimaryNavy,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: currentPasswordController,
                    obscureText: obscureCurrent,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: 'Current Master Password',
                      hintText: 'Enter current password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() => obscureCurrent = !obscureCurrent);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: 'New Master Password',
                      hintText: 'Enter new password',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() => obscureNew = !obscureNew);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      hintText: 'Confirm new password',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(() => obscureConfirm = !obscureConfirm);
                        },
                      ),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final currentPwd = currentPasswordController.text;
                        final newPwd = newPasswordController.text;
                        final confirmPwd = confirmPasswordController.text;

                        setDialogState(() {
                          isSaving = true;
                          errorMessage = null;
                        });

                        final storage = ref.read(vaultStorageServiceProvider);
                        final crypto = ref.read(vaultCryptoServiceProvider);

                        // 1. Verify current password and derive current KEK
                        final salt = await storage.getSalt();
                        final verifier = await storage.getVerifier();
                        final currentWrappedVek = await storage.getWrappedVekKek();

                        if (salt == null || verifier == null || currentWrappedVek == null) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = 'Vault credentials missing.';
                          });
                          return;
                        }

                        final currentKekResult = await crypto.deriveMasterKeyAndVerifier(
                          password: currentPwd,
                          existingSalt: salt,
                        );

                        final currentValid = crypto.constantTimeEquals(
                          currentKekResult.verifierHashBytes,
                          verifier,
                        );

                        if (!currentValid) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = 'Current password is incorrect.';
                          });
                          return;
                        }

                        // 2. Validate new password
                        final validation = crypto.validatePassword(newPwd, confirmPwd);
                        if (!validation.isValid) {
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = validation.errorMessage ?? 'Password criteria not met.';
                          });
                          return;
                        }

                        // 3. Unwrap VEK using current KEK
                        final vek = await crypto.unwrapVek(
                          wrappedVek: currentWrappedVek,
                          wrappingKey: currentKekResult.derivedKeyBytes,
                        );

                        // 4. Derive new KEK and re-wrap VEK
                        final newKekResult = await crypto.deriveMasterKeyAndVerifier(password: newPwd);
                        final newWrappedVek = await crypto.wrapVek(
                          vek: vek,
                          wrappingKey: newKekResult.derivedKeyBytes,
                        );

                        // 5. Save updated credentials with new wrapped VEK
                        await storage.saveVaultCredentials(
                          salt: newKekResult.saltBytes,
                          verifierHash: newKekResult.verifierHashBytes,
                          kdfParams: newKekResult.kdfParams,
                          wrappedVekKek: newWrappedVek,
                        );

                        ref.read(vaultSessionProvider).startSession(vek);

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Master password changed successfully!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAutoLockPicker(String currentDuration) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Auto Lock Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryNavy,
                ),
              ),
            ),
            ...['Immediately', '1 minute', '5 minutes', '15 minutes', '30 minutes'].map((duration) {
              return ListTile(
                title: Text(duration),
                trailing: currentDuration == duration ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  ref.read(vaultAuthStateProvider.notifier).setAutoLockDuration(duration);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _lockVault() {
    ref.read(vaultAuthStateProvider.notifier).lockVault();
    // GoRouter redirect automatically navigates to /unlock
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(vaultAuthStateProvider);
    final isBiometricAvailable = authState.isBiometricAvailable;
    final isBiometricEnabled = authState.isBiometricEnabled;
    final autoLockDuration = authState.autoLockDuration;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: [
            // Account & Security
            _buildSectionHeader('Account & Security'),
            Card(
              child: Column(
                children: [
                  _buildNavTile(
                    icon: Icons.key_outlined,
                    title: 'Change Master Password',
                    onTap: _showChangePasswordDialog,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
                    title: const Text('Biometric Unlock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: !isBiometricAvailable
                        ? const Text('Not enrolled or unsupported on this device', style: TextStyle(fontSize: 12))
                        : null,
                    value: isBiometricAvailable && isBiometricEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: isBiometricAvailable
                        ? (val) => ref.read(vaultAuthStateProvider.notifier).setBiometricEnabled(val)
                        : null,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.timer_outlined,
                    title: 'Auto Lock',
                    trailingText: autoLockDuration,
                    onTap: () => _showAutoLockPicker(autoLockDuration),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.security_rounded, color: AppColors.primary),
                    title: const Text('App Lock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    value: _appLock,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _appLock = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // App Preferences
            _buildSectionHeader('App Preferences'),
            Card(
              child: Column(
                children: [
                  _buildNavTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    trailingText: _selectedTheme,
                    onTap: () {
                      setState(() {
                        _selectedTheme = _selectedTheme == 'Light' ? 'Dark' : 'Light';
                      });
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.language_rounded,
                    title: 'Language',
                    trailingText: 'English',
                    onTap: () {},
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                    title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    value: _notifications,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _notifications = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Data Management
            _buildSectionHeader('Data Management'),
            Card(
              child: Column(
                children: [
                  _buildNavTile(
                    icon: Icons.cloud_sync_outlined,
                    title: 'Backup & Restore',
                    onTap: () => context.push('/backup-restore'),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.import_export_rounded,
                    title: 'Import / Export',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Import/Export format: Encrypted JSON ready.')),
                      );
                    },
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'Storage Usage',
                    trailingText: '256 MB',
                    onTap: () {},
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Recycle Bin',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recycle bin is empty')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // About
            _buildSectionHeader('About'),
            Card(
              child: _buildNavTile(
                icon: Icons.info_outline_rounded,
                title: 'App Version',
                trailingText: 'v1.0.0',
                onTap: () {},
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Lock Vault Now Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _lockVault,
                icon: const Icon(Icons.lock_rounded, color: AppColors.error, size: 20),
                label: const Text(
                  'Lock Vault Now',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimaryNavy,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildNavTile({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimaryNavy,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            Text(
              trailingText,
              style: const TextStyle(
                color: AppColors.textMutedNavy,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMutedNavy),
        ],
      ),
      onTap: onTap,
    );
  }
}
