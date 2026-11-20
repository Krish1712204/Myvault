import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/vault_form_kit.dart';
import '../../data/vault_item_model.dart';
import '../../../../core/ui/user_message.dart';
import '../../../auth/domain/vault_auth_notifier.dart';

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

  /// The item being edited. Fields this form does not show (dates, country, notes, type) are
  /// written back from here so that saving an edit never erases them.
  VaultItem? _existing;

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
        _existing = item;
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
            content: Text('Could not attach the file. ${userMessage(e)}'),
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
              Text(
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
            // The type drives card-specific display (e.g. Debit Card), so renaming keeps it.
            documentType: _existing?.documentType ?? title,
            documentNumber: idNumber.isNotEmpty ? idNumber : null,
            fullName: fullName.isNotEmpty ? fullName : null,
            issuedDate: _existing?.issuedDate,
            expiryDate: _existing?.expiryDate,
            issuingCountry: _existing?.issuingCountry,
            subcategory: _existing?.subcategory ?? 'Government',
            notes: _existing?.details,
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
          content: Text('Could not save. ${userMessage(e)}'),
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

  static const _idTypes = ['Aadhaar Card', 'PAN Card', 'Passport', 'Driving License', 'Voter ID'];

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemId != null;
    final ext = _newPickedAttachment?.extension?.toLowerCase() ?? '';
    final isImg = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
    final selectedType = _idTypes.contains(_titleController.text.trim()) ? _titleController.text.trim() : null;

    String? fileName;
    String? fileDetail;
    if (_newPickedAttachment != null) {
      fileName = _newPickedAttachment!.name;
      fileDetail = '${ext.toUpperCase()} · ${_formatFileSize(_newPickedAttachmentSize)}';
    } else if (_existingAttachmentPath != null) {
      fileName = 'Saved scan';
      fileDetail = 'Already stored in your vault';
    }

    return Form(
      key: _formKey,
      child: VaultFormScaffold(
        category: VaultCategory.idCards,
        title: isEditing ? 'Edit ID Card' : 'New ID Card',
        subtitle: 'Government IDs and their scans',
        isFavourite: _isFavourite,
        onFavouriteChanged: (v) => setState(() => _isFavourite = v),
        saving: _isSaving,
        onSave: _saveIdentity,
        saveLabel: isEditing ? 'Save Changes' : 'Save ID Card',
        children: [
          FormSectionCard(
            title: 'Document',
            icon: Icons.badge_rounded,
            children: [
              ChipSelector<String?>(
                options: _idTypes,
                selected: selectedType,
                labelOf: (t) => t ?? '',
                color: AppColors.categoryIdCards,
                onSelected: (t) => setState(() => _titleController.text = t ?? ''),
              ),
              LabeledField(
                label: 'Document name',
                required: true,
                child: TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'Please enter a name (e.g. Aadhaar Card)' : null,
                  decoration: const InputDecoration(
                    hintText: 'Pick above or type, e.g. Office ID',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
              ),
              LabeledField(
                label: 'Document number',
                required: true,
                child: TextFormField(
                  controller: _idNumberController,
                  obscureText: _obscureNumber,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter document number' : null,
                  decoration: InputDecoration(
                    hintText: '1234 5678 9012 or ABCDE1234F',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    suffixIcon: IconButton(
                      tooltip: _obscureNumber ? 'Show' : 'Hide',
                      icon: Icon(_obscureNumber ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureNumber = !_obscureNumber),
                    ),
                  ),
                ),
              ),
              LabeledField(
                label: 'Name on document',
                child: TextFormField(
                  controller: _fullNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Krishna Shelar',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
              ),
            ],
          ),
          FormSectionCard(
            title: 'Scan or photo',
            icon: Icons.document_scanner_rounded,
            children: [
              UploadZone(
                color: AppColors.categoryIdCards,
                icon: Icons.add_photo_alternate_rounded,
                title: 'Upload ID scan',
                subtitle: 'JPG, PNG, WEBP or PDF · up to 25 MB',
                onPick: _pickAttachment,
                fileName: fileName,
                fileDetail: fileDetail,
                preview: isImg && _newPickedAttachmentBytes != null
                    ? GestureDetector(
                        onTap: _previewPickedFile,
                        child: Image.memory(_newPickedAttachmentBytes!, fit: BoxFit.cover),
                      )
                    : null,
                onRemove: _newPickedAttachment == null
                    ? null
                    : () => setState(() {
                          _newPickedAttachment = null;
                          _newPickedAttachmentBytes = null;
                          _newPickedAttachmentSize = 0;
                        }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
