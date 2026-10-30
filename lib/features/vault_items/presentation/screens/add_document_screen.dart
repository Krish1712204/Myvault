import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../data/vault_item_model.dart';

class AddDocumentScreen extends ConsumerStatefulWidget {
  final String? itemId;
  final VaultCategory initialCategory;

  const AddDocumentScreen({
    super.key,
    this.itemId,
    this.initialCategory = VaultCategory.documents,
  });

  @override
  ConsumerState<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends ConsumerState<AddDocumentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();

  late VaultCategory _selectedCategory;
  bool _isFavourite = false;
  bool _isSaving = false;
  bool _initialized = false;

  PlatformFile? _pickedFile;
  Uint8List? _pickedFileBytes;
  int _pickedFileSize = 0;
  String? _existingFileName;
  int? _existingFileSize;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && widget.itemId != null) {
      _initialized = true;
      final allItems = ref.read(vaultItemsProvider);
      final item = allItems.firstWhere(
        (i) => i.id == widget.itemId,
        orElse: () => const VaultItem(
          id: '',
          title: '',
          subtitle: '',
          category: VaultCategory.documents,
        ),
      );

      if (item.id.isNotEmpty) {
        _titleController.text = item.title;
        _selectedCategory = item.category;
        _isFavourite = item.isFavourite;
        _existingFileName = item.fileName ?? item.title;
        _existingFileSize = item.fileSize;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final size = file.lengthSync() ?? await file.length() ?? bytes.length;
        if (size > 50 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File exceeds maximum size limit of 50 MB.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _pickedFile = file;
          _pickedFileBytes = bytes;
          _pickedFileSize = size;

          // If title is empty, auto-populate from file name without extension
          if (_titleController.text.trim().isEmpty) {
            final nameWithoutExt = file.name.contains('.')
                ? file.name.substring(0, file.name.lastIndexOf('.'))
                : file.name;
            _titleController.text = nameWithoutExt;
          }

          final ext = file.extension?.toLowerCase() ?? '';
          if (ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp') {
            _selectedCategory = VaultCategory.photos;
          } else {
            _selectedCategory = VaultCategory.documents;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openPreviewBeforeSave() {
    if (_pickedFileBytes == null) return;
    final ext = _pickedFile?.extension?.toLowerCase() ?? '';
    final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';

    if (isImage) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.memory(_pickedFileBytes!),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(_pickedFile?.name ?? 'File Preview'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                ext == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                size: 48,
                color: ext == 'pdf' ? Colors.red : AppColors.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Size: ${_formatFileSize(_pickedFileSize)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'File is verified and ready to be securely stored.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveDocument() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.itemId != null;
    if (!isEditing && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap below to choose a file from your device.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim();

      if (_pickedFile != null && _pickedFileBytes != null) {
        await ref.read(vaultItemsProvider.notifier).saveDocumentItem(
              id: widget.itemId,
              title: title,
              category: _selectedCategory,
              originalFileName: _pickedFile!.name,
              fileBytes: _pickedFileBytes!,
              notes: null,
              isFavourite: _isFavourite,
            );
      } else if (isEditing) {
        await ref.read(vaultItemsProvider.notifier).updateDocumentMetadata(
              id: widget.itemId!,
              title: title,
              category: _selectedCategory,
              notes: null,
              isFavourite: _isFavourite,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Saved successfully' : 'Imported successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 KB';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemId != null;
    final ext = _pickedFile?.extension?.toLowerCase() ?? '';
    final isImage = ext == 'jpg' || ext == 'jpeg' || ext == 'png' || ext == 'webp';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Edit Item' : 'Import File',
          style: const TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Favorite Star at the top only
          IconButton(
            icon: Icon(
              _isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _isFavourite ? Colors.amber : AppColors.textMutedNavy,
              size: 26,
            ),
            tooltip: _isFavourite ? 'Marked as Favourite' : 'Mark as Favourite',
            onPressed: () => setState(() => _isFavourite = !_isFavourite),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _isSaving ? null : _saveDocument,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // File Picker Box & Live Preview
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _pickedFile != null ? AppColors.primary : AppColors.border,
                      width: _pickedFile != null ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_pickedFile != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isImage ? AppColors.categoryPhotosBg : AppColors.categoryDocumentsBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isImage ? Icons.image_rounded : (ext == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded),
                                  color: isImage ? AppColors.categoryPhotos : AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pickedFile!.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimaryNavy,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatFileSize(_pickedFileSize)} · Ready to save',
                                      style: const TextStyle(color: AppColors.textMutedNavy, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
                                tooltip: 'Replace File',
                                onPressed: _pickFile,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // PREVIEW OPTION BEFORE SAVE
                          if (isImage && _pickedFileBytes != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(maxHeight: 180),
                                width: double.infinity,
                                color: Colors.black12,
                                child: Image.memory(
                                  _pickedFileBytes!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Interactive Preview Button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openPreviewBeforeSave,
                              icon: const Icon(Icons.visibility_rounded, size: 18),
                              label: const Text('Preview File Before Saving'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ] else if (isEditing && _existingFileName != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _existingFileName!,
                                      style: const TextStyle(
                                        color: AppColors.textPrimaryNavy,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_formatFileSize(_existingFileSize)} · Saved on device',
                                      style: const TextStyle(color: AppColors.textMutedNavy, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.sync_rounded, size: 16),
                                label: const Text('Replace'),
                                onPressed: _pickFile,
                              ),
                            ],
                          ),
                        ] else ...[
                          InkWell(
                            onTap: _pickFile,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.drive_folder_upload_outlined,
                                      size: 36,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Tap to choose file from device',
                                    style: TextStyle(
                                      color: AppColors.textPrimaryNavy,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Supports PDF, Word, Excel, ZIP, APK, Images (Max 50 MB)',
                                    style: TextStyle(
                                      color: AppColors.textMutedNavy,
                                      fontSize: 12,
                                    ),
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
                const SizedBox(height: AppSpacing.md),

                // Category Selection
                const Text(
                  'Vault Category',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 18,
                          color: _selectedCategory == VaultCategory.documents ? Colors.white : AppColors.categoryDocuments,
                        ),
                        label: const Center(child: Text('Documents / Files')),
                        selected: _selectedCategory == VaultCategory.documents,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _selectedCategory == VaultCategory.documents ? Colors.white : AppColors.textPrimaryNavy,
                          fontWeight: _selectedCategory == VaultCategory.documents ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = VaultCategory.documents);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        avatar: Icon(
                          Icons.image_outlined,
                          size: 18,
                          color: _selectedCategory == VaultCategory.photos ? Colors.white : AppColors.categoryPhotos,
                        ),
                        label: const Center(child: Text('Photos / Media')),
                        selected: _selectedCategory == VaultCategory.photos,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: _selectedCategory == VaultCategory.photos ? Colors.white : AppColors.textPrimaryNavy,
                          fontWeight: _selectedCategory == VaultCategory.photos ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedCategory = VaultCategory.photos);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Title Field
                const Text(
                  'Title *',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a title' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g. Passport, Tax Return, Resume, Family Photo',
                    prefixIcon: const Icon(Icons.title_rounded, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
