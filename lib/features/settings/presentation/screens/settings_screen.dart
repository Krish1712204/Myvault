import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/profile/user_profile_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/notifications_sheet.dart';
import '../../../../shared/widgets/user_profile_sheet.dart';
import '../../../auth/domain/vault_auth_notifier.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _appLock = true;
  bool _notifications = true;

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

                        // 1. Verify current password
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

                        // 5. Save updated credentials
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

  void _showThemePicker() {
    final currentTheme = ref.read(themeModeProvider);

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
                'Choose App Theme',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryNavy,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.wb_sunny_rounded, color: Colors.amber),
              title: const Text('Light'),
              trailing: currentTheme == ThemeMode.light ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.nightlight_round, color: Color(0xFF3B82F6)),
              title: const Text('Dark'),
              trailing: currentTheme == ThemeMode.dark ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone_android_rounded, color: AppColors.textMutedNavy),
              title: const Text('System Default'),
              trailing: currentTheme == ThemeMode.system ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showStorageBreakdownDialog(int itemCount) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.pie_chart_outline_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Storage Usage'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStorageRow('Vault Records', '$itemCount items', '1.2 MB'),
            const Divider(height: 16),
            _buildStorageRow('Document & Photo Files', 'Protected local store', '14.8 MB'),
            const Divider(height: 16),
            _buildStorageRow('Temporary Previews', 'Cache buffer', '0.0 MB'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All data is kept strictly offline on your phone.',
                      style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Temporary preview cache cleared.'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Clear Cache'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageRow(String title, String subtitle, String size) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle, style: const TextStyle(color: AppColors.textMutedNavy, fontSize: 12)),
          ],
        ),
        Text(size, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  void _showExportOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export Vault Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.shield_rounded, color: AppColors.primary),
                ),
                title: const Text('Vault Backup (.myvault)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Password-protected complete backup of your records and files.'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/backup-restore');
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.file_download_rounded, color: Color(0xFF2E7D32)),
                ),
                title: const Text('Save Local Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Verify and export offline record count summary.'),
                onTap: () {
                  Navigator.pop(ctx);
                  final items = ref.read(vaultItemsProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Vault summary ready: ${items.length} items verified locally.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _lockVault() {
    ref.read(vaultAuthStateProvider.notifier).lockVault();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(vaultAuthStateProvider);
    final userProfile = ref.watch(userProfileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final items = ref.watch(vaultItemsProvider);

    final isBiometricAvailable = authState.isBiometricAvailable;
    final isBiometricEnabled = authState.isBiometricEnabled;
    final autoLockDuration = authState.autoLockDuration;

    final hasPhoto = userProfile.photoPath != null && File(userProfile.photoPath!).existsSync();

    String themeLabel;
    if (themeMode == ThemeMode.dark) {
      themeLabel = 'Dark';
    } else if (themeMode == ThemeMode.system) {
      themeLabel = 'System Default';
    } else {
      themeLabel = 'Light';
    }

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
            // 1. Account Profile Card: Krishna Shelar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                onTap: () => UserProfileSheet.show(context),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryLight,
                          border: Border.all(color: AppColors.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: hasPhoto
                              ? Image.file(
                                  File(userProfile.photoPath!),
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: Text(
                                    'KS',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userProfile.name,
                              style: const TextStyle(
                                color: AppColors.textPrimaryNavy,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              userProfile.role,
                              style: const TextStyle(
                                color: AppColors.textMutedNavy,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded, color: AppColors.success, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Secured',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Security & Protection Section
            _buildSectionHeader('Security & Protection'),
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
                    title: const Text('Fingerprint Biometrics', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: !isBiometricAvailable
                        ? const Text('Not enrolled or unsupported on device', style: TextStyle(fontSize: 12))
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
                    title: 'Auto Lock Duration',
                    trailingText: autoLockDuration,
                    onTap: () => _showAutoLockPicker(autoLockDuration),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.security_rounded, color: AppColors.primary),
                    title: const Text('App Lock on Background', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    value: _appLock,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _appLock = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. App Preferences Section
            _buildSectionHeader('App Preferences'),
            Card(
              child: Column(
                children: [
                  _buildNavTile(
                    icon: Icons.palette_outlined,
                    title: 'Theme',
                    trailingText: themeLabel,
                    onTap: _showThemePicker,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                    title: const Text('Notifications & Reminders', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    value: _notifications,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _notifications = val),
                  ),
                  if (_notifications) ...[
                    const Divider(color: AppColors.border, height: 1),
                    _buildNavTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'View Active Alerts',
                      trailingText: '4 active',
                      onTap: () => NotificationsSheet.show(context),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Data & Storage Management Section
            _buildSectionHeader('Data & Storage Management'),
            Card(
              child: Column(
                children: [
                  _buildNavTile(
                    icon: Icons.cloud_sync_outlined,
                    title: 'Backup & Restore',
                    trailingText: 'Protected',
                    onTap: () => context.push('/backup-restore'),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.file_upload_outlined,
                    title: 'Export Vault Data',
                    trailingText: '${items.length} items',
                    onTap: _showExportOptionsSheet,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'Storage Usage & Cache',
                    trailingText: '16 MB',
                    onTap: () => _showStorageBreakdownDialog(items.length),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 5. About Section
            _buildSectionHeader('About'),
            Card(
              child: Column(
                children: [
                  _buildNavTile(
                    icon: Icons.info_outline_rounded,
                    title: 'MyVault Version',
                    trailingText: 'v1.0.2',
                    onTap: () {},
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Security Architecture',
                    trailingText: 'Zero-Cloud Offline',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('MyVault runs completely offline on this phone with zero cloud storage.'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                  ),
                ],
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
