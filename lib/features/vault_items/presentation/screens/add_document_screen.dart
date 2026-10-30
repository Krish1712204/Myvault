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
  final _notesController = TextEditingController();

  late VaultCategory _selectedCategory;
  bool _isFavourite = false;
  bool _isSaving = false;
  bool _initialized = false;

  PlatformFile? _pickedFile;
  Uint8List? _pickedFileBytes;
  int _pickedFileSize = 0;
  String? _existingFileName;
  int? _existingFileSize;

  static const List<String> _quickDocPresets = [
    'Resume',
    'Degree / Certificate',
    'Tax Document',
    'Insurance Policy',
    'Medical Report',
    'Offer Letter',
    'Payslip',
    'Aadhaar Scan',
    'PAN Scan',
    'Passport Scan',
    'Driving License',
    'Personal Photo',
  ];

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
        _notesController.text = item.details ?? '';
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
    _notesController.dispose();
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

  void _applyPreset(String preset) {
    setState(() {
      _titleController.text = preset;
      if (preset == 'Personal Photo') {
        _selectedCategory = VaultCategory.photos;
      }
    });
  }

  Future<void> _saveDocument() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.itemId != null;
    if (!isEditing && _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap above to choose a file from your device.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final title = _titleController.text.trim();
      final notes = _notesController.text.trim();

      if (_pickedFile != null && _pickedFileBytes != null) {
        await ref.read(vaultItemsProvider.notifier).saveDocumentItem(
              id: widget.itemId,
              title: title,
              category: _selectedCategory,
              originalFileName: _pickedFile!.name,
              fileBytes: _pickedFileBytes!,
              notes: notes.isNotEmpty ? notes : null,
              isFavourite: _isFavourite,
            );
      } else if (isEditing) {
        await ref.read(vaultItemsProvider.notifier).updateDocumentMetadata(
              id: widget.itemId!,
              title: title,
              category: _selectedCategory,
              notes: notes.isNotEmpty ? notes : null,
              isFavourite: _isFavourite,
            );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Document updated successfully' : '$title encrypted & saved to vault!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save document: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '—';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Edit Document' : 'Import Encrypted File',
          style: const TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
                // Quick Presets
                if (!isEditing) ...[
                  const Text(
                    'Quick Presets (1-Tap Title)',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: AppColors.textMutedNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _quickDocPresets.map((preset) {
                        final isSelected = _titleController.text.trim().toLowerCase() == preset.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            label: Text(preset),
                            backgroundColor: isSelected ? AppColors.primary : Colors.white,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimaryNavy,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            onPressed: () => _applyPreset(preset),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // File Picker Box
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
                                      '${_formatFileSize(_pickedFileSize)} · Ready to encrypt with AES-256-GCM',
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
                                      '${_formatFileSize(_existingFileSize)} · Encrypted on device',
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
                    hintText: 'e.g. Passport scan, Property deed, Resume',
                    prefixIcon: const Icon(Icons.title_rounded, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Notes Field
                const Text(
                  'Notes (Optional)',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Additional details or context about this document...',
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Mark as Favourite
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Mark as Favourite',
                      style: TextStyle(
                        color: AppColors.textPrimaryNavy,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: const Text(
                      'Show on dashboard favorites',
                      style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12),
                    ),
                    value: _isFavourite,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isFavourite = val),
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
