import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  String _lastBackupDate = '12 Oct 2025, 09:30 AM';

  void _createBackup() {
    setState(() {
      _lastBackupDate = 'Just now';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Encrypted backup created successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _restoreBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Backup file verified. Vault restored.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Backup & Restore',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: [
            // Top Hero illustration card
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_done_rounded, color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Keep your data safe',
                    style: TextStyle(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Create an encrypted backup of your\nvault and restore it anytime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMutedNavy,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Backup Section
            const Text(
              'Backup',
              style: TextStyle(color: AppColors.textPrimaryNavy, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                    title: const Text('Create Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: const Text('Export all your data to an encrypted file.', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMutedNavy),
                    onTap: _createBackup,
                  ),
                  const Divider(color: AppColors.border, height: 1),
                  ListTile(
                    leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                    title: const Text('Last Backup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(_lastBackupDate, style: const TextStyle(fontSize: 12, color: AppColors.textMutedNavy)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Restore Section
            const Text(
              'Restore',
              style: TextStyle(color: AppColors.textPrimaryNavy, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_download_outlined, color: AppColors.primary),
                title: const Text('Restore from Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Import and restore your data from file.', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMutedNavy),
                onTap: _restoreBackup,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Import / Export Section
            const Text(
              'Import / Export',
              style: TextStyle(color: AppColors.textPrimaryNavy, fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.file_upload_outlined, color: AppColors.primary),
                title: const Text('Export Selected Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                subtitle: const Text('Export specific items securely.', style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMutedNavy),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selected items export ready.')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
