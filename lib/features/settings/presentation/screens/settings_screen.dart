import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricUnlock = true;
  bool _appLock = true;
  bool _notifications = true;
  String _autoLockDuration = '5 minutes';
  String _selectedTheme = 'Light';

  void _showChangePasswordDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Master Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'New master password',
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Master password updated successfully')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAutoLockPicker() {
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
              ),
            ),
            ...['Immediately', '1 minute', '5 minutes', '15 minutes', '30 minutes'].map((duration) {
              return ListTile(
                title: Text(duration),
                trailing: _autoLockDuration == duration ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  setState(() => _autoLockDuration = duration);
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
    ref.read(authStateProvider.notifier).lockVault();
    context.go('/unlock');
  }

  @override
  Widget build(BuildContext context) {
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
                    value: _biometricUnlock,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _biometricUnlock = val),
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  _buildNavTile(
                    icon: Icons.timer_outlined,
                    title: 'Auto Lock',
                    trailingText: _autoLockDuration,
                    onTap: _showAutoLockPicker,
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
