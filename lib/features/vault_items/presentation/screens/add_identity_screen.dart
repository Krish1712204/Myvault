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
  final _countryController = TextEditingController(text: 'India');
  final _issuedDateController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _notesController = TextEditingController();

  String _documentType = 'Aadhaar Card';
  String _subcategory = 'Government';
  bool _noExpiry = false;
  bool _isFavourite = false;
  bool _obscureNumber = true;
  bool _isSaving = false;
  bool _initialized = false;

  // Attachment handling
  String? _existingAttachmentPath;
  PlatformFile? _newPickedAttachment;
  Uint8List? _newPickedAttachmentBytes;
  int _newPickedAttachmentSize = 0;

  final List<String> _idTypes = [
    'Aadhaar Card',
    'PAN Card',
    'Passport',
    'Driving License',
    'Voter ID',
    'Custom ID',
  ];

  final List<String> _subcategories = [
    'Government',
    'Personal',
    'Work',
    'Other',
  ];

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
        _documentType = _idTypes.contains(item.documentType)
            ? item.documentType!
            : (_idTypes.contains(item.title) ? item.title : 'Custom ID');
        _idNumberController.text = item.documentNumber ?? '';
        _fullNameController.text = item.fullName ?? '';
        _countryController.text = item.issuingCountry ?? 'India';
        _issuedDateController.text = item.issuedDate ?? '';
        _expiryDateController.text = item.expiryDate ?? '';
        _noExpiry = item.expiryDate == null || item.expiryDate == 'Does not expire' || item.expiryDate!.isEmpty;
        _notesController.text = item.details ?? '';
        _subcategory = _subcategories.contains(item.subcategory) ? item.subcategory! : 'Government';
        _isFavourite = item.isFavourite;
        _existingAttachmentPath = item.attachmentPath;
      }
    } else if (!_initialized) {
      _initialized = true;
      _titleController.text = _documentType;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _idNumberController.dispose();
    _fullNameController.dispose();
    _countryController.dispose();
    _issuedDateController.dispose();
    _expiryDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1950),
      lastDate: DateTime(2050),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimaryNavy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      setState(() {
        controller.text = '${picked.day} ${months[picked.month - 1]} ${picked.year}';
      });
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
      final country = _countryController.text.trim();
      final issuedDate = _issuedDateController.text.trim();
      final expiryDate = _noExpiry ? 'Does not expire' : _expiryDateController.text.trim();
      final notes = _notesController.text.trim();

      await ref.read(vaultItemsProvider.notifier).saveIdentityItem(
            id: widget.itemId,
            title: title,
            documentType: _documentType,
            documentNumber: idNumber.isNotEmpty ? idNumber : null,
            fullName: fullName.isNotEmpty ? fullName : null,
            issuedDate: issuedDate.isNotEmpty ? issuedDate : null,
            expiryDate: expiryDate.isNotEmpty ? expiryDate : null,
            issuingCountry: country.isNotEmpty ? country : null,
            subcategory: _subcategory,
            notes: notes.isNotEmpty ? notes : null,
            attachmentPath: attachmentPath,
            isFavourite: _isFavourite,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.itemId != null ? 'ID Card updated successfully' : 'ID Card saved securely'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save ID card: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
          isEditing ? 'Edit ID Card' : 'Add ID Card',
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
                // Document Type Dropdown
                const Text(
                  'Document Type *',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _documentType,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _idTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _documentType = val;
                        if (!isEditing || _titleController.text.isEmpty) {
                          _titleController.text = val;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Title Field
                const Text(
                  'Card Title *',
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
                    hintText: 'e.g. Aadhaar Card, Passport',
                    prefixIcon: const Icon(Icons.title_rounded, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ID Number Field
                const Text(
                  'ID / Document Number',
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
                  decoration: InputDecoration(
                    hintText: 'e.g. 1234 5678 9012 or ABCDE1234F',
                    prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.textMutedNavy),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNumber ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textMutedNavy,
                      ),
                      onPressed: () {
                        setState(() => _obscureNumber = !_obscureNumber);
                      },
                    ),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Holder Full Name Field
                const Text(
                  'Full Name / Holder Name',
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
                    hintText: 'e.g. Prathamesh Shelar',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Subcategory Selection
                const Text(
                  'Category',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _subcategories.map((sub) {
                    final selected = _subcategory == sub;
                    return ChoiceChip(
                      label: Text(sub),
                      selected: selected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimaryNavy,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _subcategory = sub);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),

                // Issued Date & Country
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Issue Date',
                            style: TextStyle(
                              color: AppColors.textPrimaryNavy,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _issuedDateController,
                            readOnly: true,
                            onTap: () => _selectDate(context, _issuedDateController),
                            decoration: InputDecoration(
                              hintText: 'Select date',
                              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textMutedNavy),
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Issuing Country',
                            style: TextStyle(
                              color: AppColors.textPrimaryNavy,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _countryController,
                            decoration: InputDecoration(
                              hintText: 'e.g. India',
                              prefixIcon: const Icon(Icons.flag_outlined, size: 18, color: AppColors.textMutedNavy),
                              fillColor: Colors.white,
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Expiry Date / No Expiry Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Expiry Date',
                      style: TextStyle(
                        color: AppColors.textPrimaryNavy,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        const Text('No Expiry', style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13)),
                        Switch(
                          value: _noExpiry,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _noExpiry = val;
                              if (val) _expiryDateController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (!_noExpiry) ...[
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _expiryDateController,
                    readOnly: true,
                    onTap: () => _selectDate(context, _expiryDateController),
                    decoration: InputDecoration(
                      hintText: 'Select expiry date',
                      prefixIcon: const Icon(Icons.event_outlined, size: 18, color: AppColors.textMutedNavy),
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),

                // Attachment Section
                const Text(
                  'Card Photo or Document Attachment (Optional)',
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
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (_newPickedAttachment != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                              const SizedBox(width: 10),
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
                                    Text(
                                      '${(_newPickedAttachmentSize / 1024).toStringAsFixed(1)} KB (Ready to encrypt)',
                                      style: const TextStyle(color: AppColors.textMutedNavy, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppColors.error),
                                onPressed: () => setState(() {
                                  _newPickedAttachment = null;
                                  _newPickedAttachmentBytes = null;
                                  _newPickedAttachmentSize = 0;
                                }),
                              ),
                            ],
                          ),
                        ] else if (_existingAttachmentPath != null && _existingAttachmentPath!.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(Icons.lock_rounded, color: AppColors.primary, size: 24),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Encrypted attachment attached to ID',
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                onPressed: () => setState(() => _existingAttachmentPath = null),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              const Icon(Icons.attach_file_rounded, color: AppColors.textMutedNavy),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'No file attached (JPG, PNG, PDF up to 25MB)',
                                  style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12),
                                ),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.upload_file_rounded, size: 16),
                                label: const Text('Pick File'),
                                onPressed: _pickAttachment,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Additional details, security PIN, or reminders...',
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Mark as Favourite Switch
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
                      'Quick access from dashboard favorites',
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
