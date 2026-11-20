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
  bool _isFavourite = false;
  String _selectedCategory = 'Personal';

  static const List<String> _categories = [
    'Personal',
    'Work',
    'Family',
    'Emergency',
    'Other',
  ];

  /// The item being edited. Fields this form does not show (company, address, notes, …) are
  /// written back from here so that saving an edit never erases them.
  VaultItem? _existing;
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
        _existing = item;
        _nameController.text = item.title;
        _phoneController.text = item.phoneNumber ?? (item.details?.startsWith('+') == true ? item.details! : '');
        _emailController.text = item.email ?? item.username ?? '';
        _existingAttachmentPath = item.attachmentPath;
        _isFavourite = item.isFavourite;
        if (item.subcategory != null && item.subcategory!.isNotEmpty) {
          _selectedCategory = item.subcategory!;
        }
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
      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final files = await FilePicker.pickFiles(
        type: FileType.image,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        // The picker leaves an unencrypted copy in the app cache; remove it now.
        FilePicker.clearTemporaryFiles().ignore();
        setState(() {
          _photoBytes = bytes;
          _photoRemoved = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not select the image. ${userMessage(e)}'),
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
            company: _existing?.company,
            jobTitle: _existing?.jobTitle,
            address: _existing?.address,
            birthday: _existing?.birthday,
            notes: _existing?.details,
            tags: _existing?.tags,
            secondaryPhone: _existing?.secondaryPhone,
            secondaryEmail: _existing?.secondaryEmail,
            attachmentPath: attachmentPath,
            category: _selectedCategory,
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
          content: Text('Could not save the contact. ${userMessage(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  static const _categoryIcons = {
    'Personal': Icons.person_rounded,
    'Work': Icons.work_rounded,
    'Family': Icons.family_restroom_rounded,
    'Emergency': Icons.emergency_rounded,
    'Other': Icons.more_horiz_rounded,
  };

  /// Decrypting the saved photo once, not on every rebuild.
  Future<Uint8List>? _existingPhoto;

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemId != null;
    const accent = AppColors.categoryContacts;

    return Form(
      key: _formKey,
      child: VaultFormScaffold(
        category: VaultCategory.contacts,
        title: isEditing ? 'Edit Contact' : 'New Contact',
        subtitle: 'People and numbers you want kept private',
        isFavourite: _isFavourite,
        onFavouriteChanged: (v) => setState(() => _isFavourite = v),
        saving: _isSaving,
        onSave: _saveContact,
        saveLabel: isEditing ? 'Save Changes' : 'Save Contact',
        children: [
          FormSectionCard(
            title: 'Photo',
            icon: Icons.photo_camera_rounded,
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 108,
                      height: 108,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFF34D399), Color(0xFF38BDF8)],
                        ),
                        boxShadow: [
                          BoxShadow(color: accent.withAlpha(60), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          color: AppColors.categoryContactsBg,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: KeyedSubtree(
                              key: ValueKey('${_photoBytes?.length}-$_photoRemoved'),
                              child: _buildAvatarImage(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: _AvatarAction(
                        color: accent,
                        icon: Icons.photo_camera_rounded,
                        tooltip: 'Choose photo',
                        onTap: _pickPhoto,
                      ),
                    ),
                    if (_hasPhoto)
                      Positioned(
                        left: -2,
                        bottom: -2,
                        child: _AvatarAction(
                          color: AppColors.error,
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Remove photo',
                          onTap: _removePhoto,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                _hasPhoto ? 'Tap the camera to change the photo' : 'Add a photo (optional)',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          FormSectionCard(
            title: 'Details',
            icon: Icons.contact_page_rounded,
            children: [
              LabeledField(
                label: 'Full name',
                required: true,
                child: TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter contact name' : null,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Prathamesh Shelar',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
              ),
              LabeledField(
                label: 'Mobile number',
                required: true,
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter mobile number' : null,
                  decoration: const InputDecoration(
                    hintText: '+91 98765 43210',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                ),
              ),
              LabeledField(
                label: 'Email',
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
              ),
            ],
          ),
          FormSectionCard(
            title: 'Category',
            icon: Icons.label_rounded,
            children: [
              ChipSelector<String>(
                options: _categories,
                selected: _selectedCategory,
                labelOf: (c) => c,
                iconOf: (c) => _categoryIcons[c] ?? Icons.label_rounded,
                color: accent,
                onSelected: (c) => setState(() => _selectedCategory = c),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasPhoto => _photoBytes != null || (_existingAttachmentPath != null && !_photoRemoved);

  Widget _buildAvatarImage() {
    if (_photoBytes != null) {
      return Image.memory(_photoBytes!, fit: BoxFit.cover, width: 102, height: 102);
    }

    if (_existingAttachmentPath != null && !_photoRemoved) {
      _existingPhoto ??= ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(_existingAttachmentPath!);
      return FutureBuilder<Uint8List>(
        future: _existingPhoto,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.memory(snapshot.data!, fit: BoxFit.cover, width: 102, height: 102);
          }
          return const Center(
            child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      );
    }

    final initials = _nameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Center(
      child: initials.isEmpty
          ? const Icon(Icons.person_rounded, size: 50, color: AppColors.categoryContacts)
          : Text(
              initials,
              style: const TextStyle(color: AppColors.categoryContacts, fontSize: 34, fontWeight: FontWeight.w800),
            ),
    );
  }
}

class _AvatarAction extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _AvatarAction({required this.color, required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}
