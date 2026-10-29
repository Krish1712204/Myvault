import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  void _showGeneratePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Password Generator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generated Strong Password:',
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withAlpha(90),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'k9#Pq!7mX@vL2\$wR',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryNavy,
                    ),
                  ),
                  Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Strength: Very Strong (16 characters, alphanumeric & symbols)',
              style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/add-item');
            },
            child: const Text('Use in New Item'),
          ),
        ],
      ),
    );
  }

  void _showScannerPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document scanner ready for camera module integration.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showImportPlaceholder(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File importer ready for SAF / Android Keystore file import.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: AppColors.textPrimaryNavy,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/categories'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildActionButton(
              icon: Icons.add_rounded,
              label: 'Add Item',
              bgColor: AppColors.categoryPasswordsBg,
              iconColor: AppColors.categoryPasswords,
              onTap: () => context.push('/add-item'),
            ),
            _buildActionButton(
              icon: Icons.document_scanner_outlined,
              label: 'Scan Document',
              bgColor: AppColors.categoryNotesBg,
              iconColor: AppColors.categoryNotes,
              onTap: () => _showScannerPlaceholder(context),
            ),
            _buildActionButton(
              icon: Icons.vpn_key_outlined,
              label: 'Generate\nPassword',
              bgColor: AppColors.categoryPhotosBg,
              iconColor: AppColors.categoryPhotos,
              onTap: () => _showGeneratePasswordDialog(context),
            ),
            _buildActionButton(
              icon: Icons.drive_folder_upload_outlined,
              label: 'Import\nFile',
              bgColor: AppColors.categoryDocumentsBg,
              iconColor: AppColors.categoryDocuments,
              onTap: () => _showImportPlaceholder(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: iconColor.withAlpha(40), width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: AppColors.textPrimaryNavy,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

