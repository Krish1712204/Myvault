import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../vault_items/presentation/widgets/password_generator_sheet.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  void _showGeneratePasswordDialog(BuildContext context) {
    PasswordGeneratorSheet.show(context);
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

