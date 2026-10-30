import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../data/vault_item_model.dart';

class AddIdentityScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const AddIdentityScreen({
    super.key,
    this.itemId,
  });

  @override
  ConsumerState<AddIdentityScreen> createState() => _AddIdentityScreenState();
}

class _AddIdentityScreenState extends ConsumerState<AddIdentityScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _fullNameController = TextEditingController();

  bool _isFavourite = false;
  bool _obscureNumber = false;
  bool _isSaving = false;
  bool _initialized = false;

  // Attachment handling
  String? _existingAttachmentPath;
  PlatformFile? _newPickedAttachment;
  Uint8List? _newPickedAttachmentBytes;
  int _newPickedAttachmentSize = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && widget.itemId != null) {
      _initialized = true;
      final items = ref.read(vaultItemsProvider);
      final item = items.firstWhere(
        (i) => i.id == widget.itemId,
        orElse: () => const VaultItem(
          id: '',
          title: '',
          subtitle: '',
          category: VaultCategory.idCards,
        ),
      );
      if (item.id.isNotEmpty) {
        _titleController.text = item.title;
        _idNumberController.text = item.documentNumber ?? '';
        _fullNameController.text = item.fullName ?? '';
        _isFavourite = item.isFavourite;
        _existingAttachmentPath = item.attachmentPath;
      }
    } else if (!_initialized) {
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _idNumberController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final size = file.lengthSync() ?? await file.length() ?? bytes.length;
        if (size > 25 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File exceeds maximum size limit of 25 MB.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        setState(() {
          _newPickedAttachment = file;
          _newPickedAttachmentBytes = bytes;
          _newPickedAttachmentSize = size;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick attachment: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _previewPickedFile() {
    if (_newPickedAttachmentBytes == null) return;
    final ext = _newPickedAttachment?.extension?.toLowerCase() ?? '';
    final isImg = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);

    if (isImg) {
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
                  child: Image.memory(_newPickedAttachmentBytes!),
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
          title: Text(_newPickedAttachment?.name ?? 'ID Document Preview'),
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
                'Size: ${_formatFileSize(_newPickedAttachmentSize)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Document verified and ready to be secured in vault.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveIdentity() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? attachmentPath = _existingAttachmentPath;

      if (_newPickedAttachment != null && _newPickedAttachmentBytes != null) {
        attachmentPath = await ref.read(vaultItemsProvider.notifier).encryptAttachment(
              fileBytes: _newPickedAttachmentBytes!,
              originalFileName: _newPickedAttachment!.name,
            );
      }

      final title = _titleController.text.trim();
      final idNumber = _idNumberController.text.trim();
      final fullName = _fullNameController.text.trim();

      await ref.read(vaultItemsProvider.notifier).saveIdentityItem(
            id: widget.itemId,
            title: title,
            documentType: title,
            documentNumber: idNumber.isNotEmpty ? idNumber : null,
            fullName: fullName.isNotEmpty ? fullName : null,
            issuedDate: null,
            expiryDate: null,
            issuingCountry: null,
            subcategory: 'Government',
            notes: null,
            attachmentPath: attachmentPath,
            isFavourite: _isFavourite,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.itemId != null ? '$title updated successfully' : '$title saved to vault!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
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

    final isImg = _newPickedAttachment != null &&
        ['jpg', 'jpeg', 'png', 'webp'].contains(_newPickedAttachment?.extension?.toLowerCase());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Edit ID Card' : 'Add ID Card',
          style: const TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
              color: _isFavourite ? Colors.amber : AppColors.textMutedNavy,
            ),
            tooltip: _isFavourite ? 'Starred' : 'Mark as Favourite',
            onPressed: () => setState(() => _isFavourite = !_isFavourite),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: _isSaving ? null : _saveIdentity,
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
                // Title Field
                const Text(
                  'ID Card Name / Title *',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a title (e.g. Aadhaar Card, PAN Card)' : null,
                  decoration: InputDecoration(
                    hintText: 'e.g. Aadhaar Card, PAN Card, Driving License, Passport',
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Number Field (ID / Card Number)
                const Text(
                  'ID / Document Number *',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _idNumberController,
                  obscureText: _obscureNumber,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter document number';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'e.g. 1234 5678 9012 or ABCDE1234F',
                    prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.textMutedNavy),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNumber ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textMutedNavy,
                      ),
                      onPressed: () => setState(() => _obscureNumber = !_obscureNumber),
                    ),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Full Name on ID
                const Text(
                  'Full Name on ID Card',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Krishna Shelar',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Upload ID Card Section (Image, PDF, etc.)
                const Text(
                  'Upload ID Card (Image, PDF, etc.)',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_newPickedAttachment != null) ...[
                          Row(
                            children: [
                              if (isImg && _newPickedAttachmentBytes != null)
                                GestureDetector(
                                  onTap: _previewPickedFile,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      _newPickedAttachmentBytes!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 24),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _newPickedAttachment!.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatFileSize(_newPickedAttachmentSize),
                                      style: const TextStyle(color: AppColors.textMutedNavy, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 20),
                                tooltip: 'Preview Before Save',
                                onPressed: _previewPickedFile,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.error),
                                tooltip: 'Remove',
                                onPressed: () {
                                  setState(() {
                                    _newPickedAttachment = null;
                                    _newPickedAttachmentBytes = null;
                                    _newPickedAttachmentSize = 0;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _pickAttachment,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Replace File', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ] else if (_existingAttachmentPath != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'ID Card attached and secured',
                                  style: TextStyle(color: AppColors.textPrimaryNavy, fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _pickAttachment,
                                child: const Text('Replace File', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ] else ...[
                          InkWell(
                            onTap: _pickAttachment,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withAlpha(60), style: BorderStyle.solid),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.upload_file_rounded, size: 36, color: AppColors.primary),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tap to upload ID Card (Image or PDF)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Supports JPG, PNG, WEBP, and PDF up to 25MB',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
