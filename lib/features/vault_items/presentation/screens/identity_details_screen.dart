import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/security/clipboard_service.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../data/vault_item_model.dart';
import '../../../../core/ui/user_message.dart';
import '../../../../shared/widgets/detail_actions.dart';
import '../../../auth/domain/vault_auth_notifier.dart';

class IdentityDetailsScreen extends ConsumerStatefulWidget {
  final String itemId;

  const IdentityDetailsScreen({
    super.key,
    required this.itemId,
  });

  @override
  ConsumerState<IdentityDetailsScreen> createState() => _IdentityDetailsScreenState();
}

class _IdentityDetailsScreenState extends ConsumerState<IdentityDetailsScreen> {
  bool _showNumber = false;
  bool _isLoadingAttachment = false;
  bool _isDownloadingAttachment = false;

  Future<void> _confirmDelete(BuildContext context, VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ID Card?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.title}" and any attachments from your vault? This action cannot be undone.',
          style: TextStyle(color: AppColors.textPrimaryNavy),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMutedNavy)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final deleted = await ref.read(vaultItemsProvider.notifier).removeItem(item.id);
      if (!context.mounted) return;
      if (!deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete item. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.title} deleted from vault'),
          backgroundColor: AppColors.textPrimaryNavy,
        ),
      );
      context.pop();
    }
  }

  String _formatMaskedNumber(String? number) {
    if (number == null || number.isEmpty) return 'Not set';
    final clean = number.replaceAll(' ', '');
    if (clean.length <= 4) {
      return '•••• $clean';
    }
    final visiblePart = clean.substring(clean.length - 4);
    final maskedPart = '•••• ' * ((clean.length - 4) / 4).ceil();
    return '$maskedPart$visiblePart'.trim();
  }

  Future<void> _previewAttachment(String attachmentPath) async {
    setState(() => _isLoadingAttachment = true);
    try {
      final bytes = await ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(attachmentPath);
      if (!mounted) return;
      setState(() => _isLoadingAttachment = false);

      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('ID Attachment Preview', style: TextStyle(fontSize: 16)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 48, color: AppColors.primary),
                          const SizedBox(height: 12),
                          Text(
                            'Document attachment (Non-image file)',
                            style: TextStyle(color: AppColors.textPrimaryNavy),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingAttachment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open the scan. ${userMessage(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _downloadAttachment(VaultItem item) async {
    final attachmentPath = item.attachmentPath;
    if (attachmentPath == null || attachmentPath.isEmpty) return;

    setState(() => _isDownloadingAttachment = true);
    try {
      final bytes = await ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(attachmentPath);

      // Determine genuine file format from magic bytes (never save as .enc)
      String ext = '.jpg';
      if (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
        // %PDF
        ext = '.pdf';
      } else if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        // JPEG SOI
        ext = '.jpg';
      } else if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47 &&
          bytes[4] == 0x0D &&
          bytes[5] == 0x0A &&
          bytes[6] == 0x1A &&
          bytes[7] == 0x0A) {
        // PNG
        ext = '.png';
      } else if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        // RIFF ... WEBP
        ext = '.webp';
      }

      final cleanTitle = item.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
      final defaultFileName = '${cleanTitle.isEmpty ? "id_document" : cleanTitle}$ext';

      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Download ID Card',
        fileName: defaultFileName,
        bytes: bytes,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded: $defaultFileName'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save the scan. ${userMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingAttachment = false);
      }
    }
  }

  Future<void> _uploadAttachment(VaultItem item) async {
    try {
      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        // The picker leaves an unencrypted copy in the app cache; remove it now.
        FilePicker.clearTemporaryFiles().ignore();
        final path = await ref.read(vaultItemsProvider.notifier).encryptAttachment(
              fileBytes: bytes,
              originalFileName: file.name,
            );
        await ref.read(vaultItemsProvider.notifier).saveIdentityItem(
              id: item.id,
              title: item.title,
              documentType: item.documentType ?? item.title,
              documentNumber: item.documentNumber,
              fullName: item.fullName,
              issuedDate: item.issuedDate,
              expiryDate: item.expiryDate,
              issuingCountry: item.issuingCountry,
              subcategory: item.subcategory ?? 'Government',
              notes: item.details,
              attachmentPath: path,
              isFavourite: item.isFavourite,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID card uploaded successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload the scan. ${userMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(vaultItemsProvider);
    final matches = allItems.where((i) => i.id == widget.itemId).toList();

    if (matches.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('ID Details'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.badge_outlined, size: 48, color: AppColors.textMutedNavy),
              const SizedBox(height: 12),
              Text(
                'ID Card record not found or vault is locked',
                style: TextStyle(color: AppColors.textMutedNavy),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final item = matches.first;
    final idNumber = item.documentNumber ?? '';

    final isPaymentCard = item.documentType == 'Debit Card' || item.documentType == 'Credit Card';
    final isUpi = item.documentType == 'UPI ID';
    final numberHeading = isPaymentCard ? 'CARD NUMBER' : (isUpi ? 'UPI ID' : 'ID NUMBER');
    final nameHeading = isPaymentCard ? 'Cardholder Name' : (isUpi ? 'Account Name' : 'Holder Name');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isPaymentCard ? 'Card Details' : (isUpi ? 'UPI Details' : 'ID Card Details'),
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              item.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
              color: item.isFavourite ? Colors.amber : AppColors.textMutedNavy,
              size: 24,
            ),
            onPressed: () async {
              final saved = await ref.read(vaultItemsProvider.notifier).toggleFavourite(item.id);
              if (!saved && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not update favourite. Please try again.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textMutedNavy),
            onSelected: (val) {
              if (val == 'edit') {
                context.push('/edit-id/${item.id}');
              } else if (val == 'delete') {
                _confirmDelete(context, item);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Edit ID'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete ID', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(50),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPaymentCard ? 'BANK CARD' : (isUpi ? 'UPI' : (item.subcategory?.toUpperCase() ?? 'GOVERNMENT ID')),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.fullName != null && item.fullName!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.fullName!,
                        style: TextStyle(
                          color: Colors.white.withAlpha(220),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ID Number Sensitive Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            numberHeading,
                            style: TextStyle(
                              color: AppColors.textMutedNavy,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  _showNumber ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColors.textMutedNavy,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() => _showNumber = !_showNumber);
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                onPressed: idNumber.isNotEmpty
                                    ? () {
                                        ClipboardService.copySensitive(
                                          context: context,
                                          text: idNumber,
                                          label: '${item.title} Number',
                                        );
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _showNumber ? idNumber : _formatMaskedNumber(idNumber),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: idNumber.isNotEmpty ? AppColors.textPrimaryNavy : AppColors.textMutedNavy,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Identity Info Table Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow(nameHeading, item.fullName ?? '—'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ID Card Attachment Card (Preview & Download)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaymentCard ? 'Card Scan' : 'ID Card Document / Scan',
                        style: TextStyle(
                          color: AppColors.textPrimaryNavy,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (item.attachmentPath != null && item.attachmentPath!.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.badge_rounded, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ID Document Attached',
                                    style: TextStyle(
                                      color: AppColors.textPrimaryNavy,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Saved securely in your vault',
                                    style: TextStyle(color: AppColors.textMutedNavy, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: _isLoadingAttachment
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.visibility_outlined, size: 18),
                                label: const Text('Preview', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _isLoadingAttachment ? null : () => _previewAttachment(item.attachmentPath!),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                icon: _isDownloadingAttachment
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.download_rounded, size: 18),
                                label: const Text('Download', style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _isDownloadingAttachment ? null : () => _downloadAttachment(item),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _uploadAttachment(item),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Replace File', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          onTap: () => _uploadAttachment(item),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary.withAlpha(60)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.upload_file_rounded, size: 32, color: AppColors.primary),
                                const SizedBox(height: 8),
                                Text(
                                  isPaymentCard ? 'Upload card scan (Image / PDF)' : 'Upload ID Card (Image / PDF)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tap to select a document or scan to attach',
                                  style: TextStyle(color: AppColors.textMutedNavy, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Bottom Action Buttons
              DetailActions(
                onDelete: () => _confirmDelete(context, item),
                onEdit: () => context.push('/edit-id/${item.id}'),
                editLabel: 'Edit',
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.textMutedNavy,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimaryNavy,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
