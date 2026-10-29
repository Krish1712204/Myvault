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

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add to Vault',
                style: TextStyle(
                  color: AppColors.textPrimaryNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.categoryPasswordsBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.key_rounded, color: AppColors.categoryPasswords),
                ),
                title: const Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Website, application, or account login credentials'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add-item');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.categoryIdCardsBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.badge_outlined, color: AppColors.categoryIdCards),
                ),
                title: const Text('ID Card', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Aadhaar, PAN, Passport, Driving License, Voter ID'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add-id');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.categoryDocumentsBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.file_present_rounded, color: AppColors.categoryDocuments),
                ),
                title: const Text('Document or Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Encrypted PDF, JPG, PNG, WEBP, or TXT file'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add-document');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.categoryNotesBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sticky_note_2_rounded, color: AppColors.categoryNotes),
                ),
                title: const Text('Note', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Secure, multiline private notes with tags'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add-note');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.categoryContactsBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded, color: AppColors.categoryContacts),
                ),
                title: const Text('Contact', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Private encrypted contact with phone and email'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add-contact');
                },
              ),
            ],
          ),
        ),
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
              onTap: () => _showAddItemSheet(context),
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
              onTap: () => context.push('/add-document'),
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

