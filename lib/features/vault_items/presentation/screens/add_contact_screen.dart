import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../data/vault_item_model.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const AddContactScreen({
    super.key,
    this.itemId,
  });

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  bool _isImportingVcf = false;
  bool _isFavourite = false;

  Uint8List? _photoBytes;
  String? _existingAttachmentPath;
  bool _photoRemoved = false;

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
          category: VaultCategory.contacts,
        ),
      );
      if (item.id.isNotEmpty) {
        _nameController.text = item.title;
        _phoneController.text = item.phoneNumber ?? (item.details?.startsWith('+') == true ? item.details! : '');
        _emailController.text = item.email ?? item.username ?? '';
        _existingAttachmentPath = item.attachmentPath;
        _isFavourite = item.isFavourite;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        setState(() {
          _photoBytes = bytes;
          _photoRemoved = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not select image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _photoRemoved = true;
    });
  }

  Future<void> _uploadVcfFile() async {
    setState(() => _isImportingVcf = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final content = utf8.decode(bytes, allowMalformed: true);

        // Bulk import contacts from the VCF string in ascending order
        final count = await ref.read(vaultItemsProvider.notifier).importContactsFromVcf(content);

        if (!mounted) return;
        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported $count contacts in ascending order!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.pop();
        } else {
          // If no BEGIN:VCARD block was found, try filling current form fields
          _parseSingleVCard(content);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loaded contact details into form'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import .vcf: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingVcf = false);
      }
    }
  }

  void _parseSingleVCard(String vcf) {
    final lines = vcf.split(RegExp(r'\r?\n'));
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.startsWith('FN:')) {
        _nameController.text = line.substring(3).trim();
      } else if (line.startsWith('N:') && _nameController.text.isEmpty) {
        final parts = line.substring(2).split(';');
        final nameParts = parts.reversed.where((p) => p.trim().isNotEmpty).toList();
        _nameController.text = nameParts.join(' ').trim();
      } else if (line.startsWith('TEL') && line.contains(':')) {
        final val = line.split(':').last.trim();
        if (_phoneController.text.isEmpty) {
          _phoneController.text = val;
        }
      } else if (line.startsWith('EMAIL') && line.contains(':')) {
        final val = line.split(':').last.trim();
        if (_emailController.text.isEmpty) {
          _emailController.text = val;
        }
      }
    }
    setState(() {});
  }

  Future<void> _saveContact() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? attachmentPath = _photoRemoved ? null : _existingAttachmentPath;

      if (_photoBytes != null) {
        final cleanName = _nameController.text.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(' ', '_');
        attachmentPath = await ref.read(vaultItemsProvider.notifier).encryptAttachment(
              fileBytes: _photoBytes!,
              originalFileName: '${cleanName.isEmpty ? "contact" : cleanName}_avatar.jpg',
            );
      }

      await ref.read(vaultItemsProvider.notifier).saveContactItem(
            id: widget.itemId,
            fullName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
            attachmentPath: attachmentPath,
            isFavourite: _isFavourite,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.itemId != null ? 'Contact updated successfully' : 'Contact saved to vault',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save contact: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Edit Contact' : 'Add Contact',
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
            child: TextButton(
              onPressed: _isSaving ? null : _saveContact,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // VCF Bulk Upload Option Card
                Card(
                  elevation: 0,
                  color: AppColors.primaryLight.withAlpha(90),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppColors.primary.withAlpha(60)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.file_upload_outlined, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload .vcf File',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimaryNavy,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Import all contacts in ascending order',
                                style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: _isImportingVcf ? null : _uploadVcfFile,
                          child: _isImportingVcf
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Upload', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Contact Photo Picker & Live Preview
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.categoryContactsBg,
                                border: Border.all(color: AppColors.primary.withAlpha(70), width: 2),
                              ),
                              child: ClipOval(
                                child: _buildAvatarImage(),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.photo_camera_outlined, size: 16, color: AppColors.primary),
                            label: Text(
                              _hasPhoto ? 'Change Photo' : 'Upload Photo',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          if (_hasPhoto) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: _removePhoto,
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                              label: const Text(
                                'Remove',
                                style: TextStyle(color: AppColors.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Contact Details Form Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contact Name
                        const Text(
                          'Contact Name *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryNavy,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'Contact Name',
                            prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMutedNavy),
                            fillColor: Colors.white,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter contact name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Mobile Number
                        const Text(
                          'Mobile Number *',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryNavy,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Mobile Number',
                            prefixIcon: Icon(Icons.phone_rounded, color: AppColors.textMutedNavy),
                            fillColor: Colors.white,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter mobile number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Email (Optional)
                        const Text(
                          'Email (Optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryNavy,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Email address',
                            prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMutedNavy),
                            fillColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Save Contact Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSaving ? null : _saveContact,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Contact' : 'Save Contact',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasPhoto =>
      _photoBytes != null || (_existingAttachmentPath != null && !_photoRemoved);

  Widget _buildAvatarImage() {
    if (_photoBytes != null) {
      return Image.memory(
        _photoBytes!,
        fit: BoxFit.cover,
        width: 100,
        height: 100,
      );
    }

    if (_existingAttachmentPath != null && !_photoRemoved) {
      return FutureBuilder<Uint8List>(
        future: ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(_existingAttachmentPath!),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              width: 100,
              height: 100,
            );
          }
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      );
    }

    return const Center(
      child: Icon(Icons.person_rounded, size: 50, color: AppColors.primary),
    );
  }
}
