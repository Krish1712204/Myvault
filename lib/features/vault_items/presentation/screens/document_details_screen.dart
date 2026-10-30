import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../data/vault_item_model.dart';

class DocumentDetailsScreen extends ConsumerStatefulWidget {
  final String itemId;

  const DocumentDetailsScreen({
    super.key,
    required this.itemId,
  });

  @override
  ConsumerState<DocumentDetailsScreen> createState() => _DocumentDetailsScreenState();
}

class _DocumentDetailsScreenState extends ConsumerState<DocumentDetailsScreen> {
  bool _isLoadingPreview = false;
  bool _isDownloading = false;
  Uint8List? _previewBytes;
  String? _previewText;
  String? _previewError;
  File? _tempPreviewFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPreview();
    });
  }

  @override
  void dispose() {
    if (_tempPreviewFile != null) {
      try {
        if (_tempPreviewFile!.existsSync()) {
          _tempPreviewFile!.deleteSync();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final allItems = ref.read(vaultItemsProvider);
    final matches = allItems.where((i) => i.id == widget.itemId).toList();
    if (matches.isEmpty) return;

    final item = matches.first;
    final filePath = item.filePath;
    if (filePath == null || filePath.isEmpty) return;

    if (filePath.startsWith('seed_')) {
      setState(() {
        _previewError = 'This is a sample vault item placeholder. Real uploaded documents are encrypted and previewed on demand.';
      });
      return;
    }

    setState(() {
      _isLoadingPreview = true;
      _previewError = null;
    });

    try {
      final bytes = await ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(filePath);
      final ext = item.fileExtension?.toLowerCase() ?? '';

      if (ext == '.txt') {
        _previewText = utf8.decode(bytes, allowMalformed: true);
      }

      setState(() {
        _previewBytes = bytes;
        _isLoadingPreview = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPreview = false;
        _previewError = 'Could not preview file: ${e.toString()}';
      });
    }
  }

  Future<void> _downloadFile(VaultItem item) async {
    if (_isDownloading) return;
    final filePath = item.filePath;
    if (filePath == null || filePath.isEmpty) return;

    if (filePath.startsWith('seed_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This is a sample placeholder. Real uploaded documents can be downloaded.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);

    try {
      final bytes = await ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(filePath);
      final ext = item.fileExtension?.isNotEmpty == true
          ? (item.fileExtension!.startsWith('.') ? item.fileExtension! : '.${item.fileExtension}')
          : '';
      final defaultFileName = item.fileName ?? '${item.title}$ext';

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Download Decrypted Document',
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
            content: Text('Download failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Document?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.title}"? The encrypted file will be securely removed from app storage.',
          style: const TextStyle(color: AppColors.textPrimaryNavy),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMutedNavy)),
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
      await ref.read(vaultItemsProvider.notifier).removeItem(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.title} permanently deleted'),
          backgroundColor: AppColors.textPrimaryNavy,
        ),
      );
      context.pop();
    }
  }

  String _formatTimestamp(int? millis, String fallback) {
    if (millis == null) return fallback;
    final dt = DateTime.fromMillisecondsSinceEpoch(millis);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} $month ${dt.year}, $hour:$minute $ampm';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '—';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  Widget _buildPreviewContent(VaultItem item) {
    if (_isLoadingPreview) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Decrypting in memory...',
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_previewError != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: const Border(left: BorderSide(color: Colors.amber, width: 4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 36),
            const SizedBox(height: 8),
            Text(
              _previewError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final ext = item.fileExtension?.toLowerCase() ?? '';
    final isImage = ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp';

    if (isImage && _previewBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 340),
          color: Colors.black12,
          child: InteractiveViewer(
            maxScale: 4.0,
            child: Center(
              child: Image.memory(
                _previewBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }

    if (ext == '.txt' && _previewText != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: SingleChildScrollView(
          child: Text(
            _previewText!,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppColors.textPrimaryNavy,
            ),
          ),
        ),
      );
    }

    // PDF and other document types
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.categoryDocumentsBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              ext == '.pdf' ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
              size: 40,
              color: ext == '.pdf' ? const Color(0xFFE53935) : AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.fileName ?? item.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimaryNavy,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            _formatFileSize(item.fileSize),
            style: const TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Text(
            'Encrypted with AES-256-GCM in app-private storage.\nPlaintext copies are never persisted.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMutedNavy, fontSize: 11),
          ),
        ],
      ),
    );
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
          title: const Text('Document Details'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_off_outlined, size: 48, color: AppColors.textMutedNavy),
              const SizedBox(height: 12),
              const Text(
                'Document not found or vault is locked',
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
    final createdText = _formatTimestamp(item.createdAt, item.date);
    final updatedText = _formatTimestamp(item.updatedAt, item.date);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          item.category == VaultCategory.photos ? 'Photo Details' : 'Document Details',
          style: const TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // 1-Tap Download in AppBar
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.download_rounded, color: AppColors.primary, size: 24),
            tooltip: 'Download to Device',
            onPressed: _isDownloading ? null : () => _downloadFile(item),
          ),
          IconButton(
            icon: Icon(
              item.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
              color: item.isFavourite ? Colors.amber : AppColors.textMutedNavy,
              size: 24,
            ),
            onPressed: () {
              ref.read(vaultItemsProvider.notifier).toggleFavourite(item.id);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMutedNavy),
            onSelected: (val) {
              if (val == 'download') {
                _downloadFile(item);
              } else if (val == 'edit') {
                context.push('/edit-document/${item.id}');
              } else if (val == 'delete') {
                _confirmDelete(context, item);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Download to Device'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Edit Details'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Delete Document', style: TextStyle(color: AppColors.error)),
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
              // Preview area
              _buildPreviewContent(item),
              const SizedBox(height: AppSpacing.md),

              // Prominent Download / Save to Device Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isDownloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 22),
                label: Text(
                  _isDownloading ? 'Decrypting & Exporting...' : 'Download / Save to Device',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: _isDownloading ? null : () => _downloadFile(item),
              ),
              const SizedBox(height: AppSpacing.md),

              // File Details Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildDetailRow('Title', item.title),
                      const Divider(height: 20),
                      _buildDetailRow('Original File Name', item.fileName ?? item.title),
                      const Divider(height: 20),
                      _buildDetailRow('File Size', _formatFileSize(item.fileSize)),
                      const Divider(height: 20),
                      _buildDetailRow('MIME Type', item.mimeType ?? 'application/octet-stream'),
                      const Divider(height: 20),
                      _buildDetailRow('Category', item.category.displayName),
                      if (item.details != null && item.details!.isNotEmpty) ...[
                        const Divider(height: 20),
                        _buildDetailRow('Notes', item.details!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Timestamps Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Added',
                            style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
                          ),
                          Text(
                            createdText,
                            style: const TextStyle(
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Last Modified',
                            style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
                          ),
                          Text(
                            updatedText,
                            style: const TextStyle(
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _confirmDelete(context, item),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLight,
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text('Edit Details', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => context.push('/edit-document/${item.id}'),
                    ),
                  ),
                ],
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
          width: 130,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMutedNavy,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
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
