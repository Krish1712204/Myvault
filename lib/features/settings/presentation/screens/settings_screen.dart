import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_info.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/backup/google_drive_backup_service.dart';
import '../../../../core/profile/user_profile_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/state/vault_insights_provider.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/notifications_sheet.dart';
import '../../../../shared/widgets/user_profile_sheet.dart';
import '../../../auth/domain/vault_auth_notifier.dart';
import '../widgets/google_drive_backup_sheet.dart';
import '../../../../shared/widgets/vault_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _showGoogleDriveBackupSheet() async {
    await showGoogleDriveBackupSheet(context, ref);
    ref.invalidate(googleDriveStatusProvider);
  }

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
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
                          obscureCurrent
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(
                              () => obscureCurrent = !obscureCurrent);
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
                          obscureNew
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
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
                          obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setDialogState(
                              () => obscureConfirm = !obscureConfirm);
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

                        final error = await ref
                            .read(vaultAuthStateProvider.notifier)
                            .changeMasterPassword(
                              currentPassword: currentPwd,
                              newPassword: newPwd,
                              confirmPassword: confirmPwd,
                            );

                        if (error != null) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() {
                            isSaving = false;
                            errorMessage = error;
                          });
                          return;
                        }

                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Master password changed successfully!'),
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
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
            // Above the bottom navigation bar, not inside the current tab.
      useRootNavigator: true,
context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Auto Lock Duration',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryNavy,
                ),
              ),
            ),
            ...[
              'Immediately',
              '1 minute',
              '5 minutes',
              '15 minutes',
              '30 minutes'
            ].map((duration) {
              return ListTile(
                title: Text(duration),
                trailing: currentDuration == duration
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(vaultAuthStateProvider.notifier)
                      .setAutoLockDuration(duration);
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
            // Above the bottom navigation bar, not inside the current tab.
      useRootNavigator: true,
context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
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
              trailing: currentTheme == ThemeMode.light
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.nightlight_round, color: AppColors.primaryOnSurface),
              title: const Text('Dark'),
              trailing: currentTheme == ThemeMode.dark
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.phone_android_rounded,
                  color: AppColors.textMutedNavy),
              title: const Text('System Default'),
              trailing: currentTheme == ThemeMode.system
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                ref
                    .read(themeModeProvider.notifier)
                    .setThemeMode(ThemeMode.system);
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
            Consumer(
              builder: (context, ref, _) {
                final usage = ref.watch(storageUsageProvider).valueOrNull;
                String size(int? bytes) =>
                    bytes == null ? '…' : formatBytes(bytes);
                return Column(
                  children: [
                    _buildStorageRow('Vault Records', '$itemCount items',
                        size(usage?.databaseBytes)),
                    const Divider(height: 16),
                    _buildStorageRow('Document & Photo Files',
                        'Encrypted local store', size(usage?.fileBytes)),
                    const Divider(height: 16),
                    _buildStorageRow('Temporary Previews', 'Cache buffer',
                        size(usage?.previewBytes)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vault data stays encrypted locally. Optional Drive backups are encrypted too.',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(vaultItemsProvider.notifier)
                  .clearTemporaryPreviews();
              ref.invalidate(storageUsageProvider);
              if (!mounted) return;
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
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(subtitle,
                style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12)),
          ],
        ),
        Text(size,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
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
    final alertCount = ref.watch(visibleAlertsProvider).valueOrNull?.length;
    final storageUsage = ref.watch(storageUsageProvider).valueOrNull;
    final driveStatus = ref.watch(googleDriveStatusProvider).valueOrNull;

    final isBiometricAvailable = authState.isBiometricAvailable;
    final isBiometricEnabled = authState.isBiometricEnabled;
    final autoLockDuration = authState.autoLockDuration;

    final photo = ref.watch(profilePhotoProvider).valueOrNull;

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
        title: Text(
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
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: [
            // 1. Account Profile Card: Krishna Shelar
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppColors.border),
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
                          border:
                              Border.all(color: AppColors.primary, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: photo != null
                              ? Image.memory(
                                  photo,
                                  gaplessPlayback: true,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: userProfile.initials.isEmpty
                                      ? const Icon(Icons.person_rounded,
                                          color: AppColors.primary, size: 28)
                                      : Text(
                                          userProfile.initials,
                                          style: const TextStyle(
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
                              userProfile.hasName
                                  ? userProfile.name
                                  : 'Add your name',
                              style: TextStyle(
                                color: AppColors.textPrimaryNavy,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Row(
                              children: [
                                Icon(Icons.edit_rounded,
                                    size: 13, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Edit name & photo',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_rounded,
                                color: AppColors.success, size: 14),
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
                  Divider(color: AppColors.border, height: 1),
                  SwitchListTile(
                    secondary: _settingsIcon(Icons.fingerprint_rounded),
                    title: const Text('Fingerprint Biometrics',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: !isBiometricAvailable
                        ? const Text('Not enrolled or unsupported on device',
                            style: TextStyle(fontSize: 12))
                        : null,
                    value: isBiometricAvailable && isBiometricEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: isBiometricAvailable
                        ? (val) async {
                            final notifier =
                                ref.read(vaultAuthStateProvider.notifier);
                            final enabled =
                                await notifier.setBiometricEnabled(val);
                            final error =
                                ref.read(vaultAuthStateProvider).errorMessage;
                            if (val &&
                                !enabled &&
                                error != null &&
                                context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(error),
                                    backgroundColor: AppColors.error),
                              );
                            }
                          }
                        : null,
                  ),
                  Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.timer_outlined,
                    title: 'Auto Lock Duration',
                    trailingText: autoLockDuration,
                    onTap: () => _showAutoLockPicker(autoLockDuration),
                  ),
                  Divider(color: AppColors.border, height: 1),
                  SwitchListTile(
                    secondary: _settingsIcon(Icons.security_rounded),
                    title: const Text('Lock When Leaving App',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: const Text(
                        'Lock as soon as you switch to another app',
                        style: TextStyle(fontSize: 12)),
                    value: authState.lockOnBackground,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => ref
                        .read(vaultAuthStateProvider.notifier)
                        .setLockOnBackground(val),
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
                  Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Security Alerts',
                    trailingText: alertCount == null
                        ? ''
                        : alertCount == 0
                            ? 'All clear'
                            : '$alertCount active',
                    onTap: () => NotificationsSheet.show(context),
                  ),
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
                    trailingText: 'File',
                    onTap: () => context.push('/backup-restore'),
                  ),
                  Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.cloud_upload_outlined,
                    title: 'Google Drive Backup',
                    trailingText: switch (driveStatus) {
                      null => '',
                      GoogleDriveBackupStatus(enabled: false) => 'Off',
                      GoogleDriveBackupStatus(restorePending: true) => 'Paused',
                      GoogleDriveBackupStatus(lastError: String()) => 'Needs attention',
                      _ => 'On',
                    },
                    onTap: _showGoogleDriveBackupSheet,
                  ),
                  Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'Storage Usage & Cache',
                    trailingText: storageUsage == null
                        ? ''
                        : formatBytes(storageUsage.totalBytes),
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
                    title: 'About MyVault',
                    trailingText: 'v${AppInfo.version}',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'MyVault',
                      applicationVersion: 'v${AppInfo.version}',
                      useRootNavigator: true,
                    ),
                  ),
                  Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.verified_user_outlined,
                    title: 'How MyVault Protects You',
                    onTap: _showSecurityInfo,
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
                icon: const Icon(Icons.lock_rounded,
                    color: AppColors.error, size: 20),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
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
        style: TextStyle(
          color: AppColors.textPrimaryNavy,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  /// Settings row icon: a tinted rounded tile, matching the section icons in the forms.
  Widget _settingsIcon(IconData icon) => IconTile(icon);

  /// What protects the vault, in plain words.
  void _showSecurityInfo() {
    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _settingsIcon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: AppColors.textPrimaryNavy, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(body,
                        style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How MyVault protects you'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              point(Icons.lock_outline_rounded, 'Encrypted on this phone',
                  'Everything is encrypted with AES-256. Your master password unlocks the key and is never stored.'),
              point(Icons.wifi_off_rounded, 'Stays offline',
                  'Your vault never leaves this phone, except as an encrypted backup you create.'),
              point(Icons.fingerprint_rounded, 'Fingerprint protected',
                  "Fingerprint unlock uses a key held in the phone's secure hardware."),
              point(Icons.cloud_done_outlined, 'Encrypted backups',
                  'Backups, including Google Drive, are encrypted with a separate passphrase before they are saved.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Got it')),
        ],
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
      leading: _settingsIcon(icon),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.textPrimaryNavy,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null && trailingText.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                trailingText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMutedNavy,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: AppColors.textMutedNavy),
        ],
      ),
      onTap: onTap,
    );
  }
}
