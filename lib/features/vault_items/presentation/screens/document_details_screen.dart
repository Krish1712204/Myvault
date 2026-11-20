import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../auth/domain/vault_auth_notifier.dart';
import '../../../../core/ui/user_message.dart';
import '../../../../shared/widgets/detail_actions.dart';
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
    _cleanupTempPreview();
    super.dispose();
  }

  void _cleanupTempPreview() {
    if (_tempPreviewFile != null) {
      try {
        if (_tempPreviewFile!.existsSync()) {
          _tempPreviewFile!.deleteSync();
        }
      } catch (_) {}
      _tempPreviewFile = null;
    }
  }

  Future<void> _loadPreview() async {
    final allItems = ref.read(vaultItemsProvider);
    final matches = allItems.where((i) => i.id == widget.itemId).toList();
    if (matches.isEmpty) return;

    final item = matches.first;
    final filePath = item.filePath;
    if (filePath == null || filePath.isEmpty) return;

    setState(() {
      _isLoadingPreview = true;
      _previewError = null;
    });

    try {
      final bytes = await ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(filePath);
      final ext = item.fileExtension?.toLowerCase() ?? '';

      if (ext == '.txt' || ext == '.json' || ext == '.csv' || ext == '.log' || ext == '.md') {
        _previewText = utf8.decode(bytes, allowMalformed: true);
      }

      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _isLoadingPreview = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingPreview = false;
        _previewError = 'This file could not be opened for preview. '
            'You can still save it to your phone.';
      });
    }
  }

  /// Opens an interactive full-screen preview for images, text files, and documents/PDFs
  Future<void> _openFullscreenPreview(VaultItem item) async {
    final filePath = item.filePath;
    if (filePath == null || filePath.isEmpty) return;

    final ext = item.fileExtension?.toLowerCase() ?? '';
    final isImage =
        ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp' || ext == '.gif' || ext == '.bmp';

    // 1. Image Preview: Fullscreen Interactive Pinch-to-Zoom Viewer
    if (isImage) {
      Uint8List? bytes = _previewBytes;
      if (bytes == null) {
        setState(() => _isLoadingPreview = true);
        try {
          bytes = await ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(filePath);
          if (!mounted) return;
          setState(() {
            _previewBytes = bytes;
            _isLoadingPreview = false;
          });
        } catch (_) {
          if (!mounted) return;
          setState(() => _isLoadingPreview = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This image could not be opened.'), backgroundColor: AppColors.error),
          );
          return;
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        useSafeArea: false,
        barrierColor: Colors.black.withAlpha(240),
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black.withAlpha(160),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: Text(
              item.title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                tooltip: _saveLabel(item),
                onPressed: () => _downloadFile(item),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.memory(
                bytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
          bottomNavigationBar: Container(
            color: Colors.black.withAlpha(160),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.fileName ?? item.title,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatFileSize(item.fileSize),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    // 2. Text / Document Note Preview
    if (ext == '.txt' || ext == '.json' || ext == '.csv' || ext == '.log' || ext == '.md') {
      Uint8List? bytes = _previewBytes;
      if (bytes == null) {
        setState(() => _isLoadingPreview = true);
        try {
          bytes = await ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(filePath);
          if (!mounted) return;
          setState(() {
            _previewBytes = bytes;
            _previewText = utf8.decode(bytes!, allowMalformed: true);
            _isLoadingPreview = false;
          });
        } catch (_) {
          if (mounted) setState(() => _isLoadingPreview = false);
          return;
        }
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(
                _previewText ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    // 3. PDF / Office Document / Any File: Open in System Viewer
    try {
      final session = ref.read(vaultSessionProvider);
      final vek = session.vek;
      if (vek == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault is locked. Unlock to preview.'), backgroundColor: AppColors.error),
        );
        return;
      }

      final crypto = ref.read(vaultCryptoServiceProvider);
      final fileKey = await crypto.deriveFileStorageKey(vek);
      final fileService = ref.read(encryptedFileServiceProvider);

      final defaultName =
          item.fileName ?? 'preview_${DateTime.now().millisecondsSinceEpoch}${ext.isNotEmpty ? ext : ".pdf"}';
      final tempFile = await fileService.createTemporaryPreviewFile(
        relativePath: filePath,
        fileName: defaultName,
        fileStorageKey: fileKey,
      );
      _tempPreviewFile = tempFile;

      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final result = await OpenFilex.open(tempFile.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message.isNotEmpty && result.message != 'done'
                  ? result.message
                  : 'No default viewer found. Use Save to keep a copy on your phone.',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the file. ${userMessage(e)}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Photos export as images and documents as documents.
  static String _saveLabel(VaultItem item) => item.category == VaultCategory.photos ? 'Save Image' : 'Save Document';

  Future<void> _downloadFile(VaultItem item) async {
    if (_isDownloading) return;
    final filePath = item.filePath;
    if (filePath == null || filePath.isEmpty) return;

    setState(() => _isDownloading = true);

    try {
      final bytes = await ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(filePath);
      final ext = item.fileExtension?.isNotEmpty == true
          ? (item.fileExtension!.startsWith('.') ? item.fileExtension! : '.${item.fileExtension}')
          : '';
      final defaultFileName = item.fileName ?? '${item.title}$ext';

      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final savedPath = await FilePicker.saveFile(
        dialogTitle: _saveLabel(item),
        fileName: defaultFileName,
        bytes: bytes,
      );

      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved: $defaultFileName'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save the file. ${userMessage(e)}'),
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
        title: Text(
          'Delete Document?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.title}"? The file will be securely removed from app storage.',
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
          content: Text('${item.title} permanently deleted'),
          backgroundColor: AppColors.textPrimaryNavy,
        ),
      );
      context.pop();
    }
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              'Loading preview...',
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
          color: AppColors.surface,
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
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final ext = item.fileExtension?.toLowerCase() ?? '';
    final isImage =
        ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.webp' || ext == '.gif' || ext == '.bmp';

    if (isImage && _previewBytes != null) {
      return InkWell(
        onTap: () => _openFullscreenPreview(item),
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 340),
                width: double.infinity,
                color: Colors.black12,
                child: Center(
                  child: Image.memory(
                    _previewBytes!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(160),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Tap to zoom',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    if ((ext == '.txt' || ext == '.json' || ext == '.csv' || ext == '.log' || ext == '.md') && _previewText != null) {
      return InkWell(
        onTap: () => _openFullscreenPreview(item),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 250),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _previewText!,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: AppColors.textPrimaryNavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.open_in_full_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('Tap to expand',
                      style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // PDF and other document types: Tappable interactive preview card
    return InkWell(
      onTap: () => _openFullscreenPreview(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.categoryDocumentsBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                ext == '.pdf' ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                size: 40,
                color: ext == '.pdf' ? AppColors.categoryDocuments : AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.fileName ?? item.title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimaryNavy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _formatFileSize(item.fileSize),
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_rounded, color: AppColors.primary, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Tap to Preview Document',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
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
              Icon(Icons.folder_off_outlined, size: 48, color: AppColors.textMutedNavy),
              const SizedBox(height: 12),
              Text(
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          item.category == VaultCategory.photos ? 'Photo Details' : 'Document Details',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        // Preview and Save are the prominent buttons on the page (and in the menu), so the
        // bar keeps only the favourite star and the menu, leaving room for the title.
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
              if (val == 'preview') {
                _openFullscreenPreview(item);
              } else if (val == 'download') {
                _downloadFile(item);
              } else if (val == 'edit') {
                context.push('/edit-document/${item.id}');
              } else if (val == 'delete') {
                _confirmDelete(context, item);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'preview',
                child: Row(
                  children: [
                    Icon(Icons.visibility_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Preview Document'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    const Icon(Icons.download_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(_saveLabel(item)),
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
              // Preview Box
              _buildPreviewContent(item),
              const SizedBox(height: AppSpacing.md),

              // Side-by-side Action Buttons: Preview & Download
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.visibility_rounded, size: 20),
                      label: Text(
                        item.category == VaultCategory.photos ? 'Preview Photo' : 'Preview Document',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () => _openFullscreenPreview(item),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.download_rounded, size: 20),
                      label: Text(
                        _isDownloading ? 'Saving...' : _saveLabel(item),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _isDownloading ? null : () => _downloadFile(item),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // File Details Card
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
                      _buildDetailRow('Title', item.title),
                      const Divider(height: 20),
                      _buildDetailRow('Category', item.category.displayName),
                      const Divider(height: 20),
                      _buildDetailRow('File Size', _formatFileSize(item.fileSize)),
                      if (item.category != VaultCategory.photos) ...[
                        const Divider(height: 20),
                        _buildDetailRow('Format', item.fileExtension?.toUpperCase().replaceAll('.', '') ?? 'FILE'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons: Delete & Edit
              DetailActions(
                onDelete: () => _confirmDelete(context, item),
                onEdit: () => context.push('/edit-document/${item.id}'),
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
          width: 130,
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
