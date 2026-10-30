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
  bool _obscureNumber = false;
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
    'Debit Card',
    'Credit Card',
    'UPI ID',
    'Voter ID',
    'Custom ID',
  ];

  final List<String> _subcategories = [
    'Government',
    'Finance',
    'Personal',
    'Work',
    'Other',
  ];

  static const List<Map<String, String>> _quickPresets = [
    {'type': 'Aadhaar Card', 'title': 'Aadhaar Card', 'cat': 'Government'},
    {'type': 'PAN Card', 'title': 'PAN Card', 'cat': 'Government'},
    {'type': 'Passport', 'title': 'Passport', 'cat': 'Government'},
    {'type': 'Driving License', 'title': 'Driving License', 'cat': 'Government'},
    {'type': 'Debit Card', 'title': 'Debit Card', 'cat': 'Finance'},
    {'type': 'Credit Card', 'title': 'Credit Card', 'cat': 'Finance'},
    {'type': 'UPI ID', 'title': 'UPI ID', 'cat': 'Finance'},
    {'type': 'Voter ID', 'title': 'Voter ID', 'cat': 'Government'},
  ];

  bool get _isPaymentCard => _documentType == 'Debit Card' || _documentType == 'Credit Card';
  bool get _isUpi => _documentType == 'UPI ID';

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
        _countryController.text = item.issuingCountry ?? (_isPaymentCard ? 'HDFC Bank' : 'India');
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

  void _applyQuickPreset(Map<String, String> preset) {
    setState(() {
      _documentType = preset['type']!;
      _titleController.text = preset['title']!;
      _subcategory = preset['cat']!;
      if (_isPaymentCard) {
        if (_countryController.text == 'India') _countryController.text = '';
      } else if (_isUpi) {
        if (_countryController.text == 'India') _countryController.text = 'Google Pay / HDFC';
      } else {
        if (_countryController.text.isEmpty) _countryController.text = 'India';
      }
    });
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

    final numberLabel = _isPaymentCard
        ? 'Last 4 Digits *'
        : (_isUpi ? 'UPI ID *' : 'ID / Document Number *');
    final numberHint = _isPaymentCard
        ? 'e.g. 4821 (Never enter CVV or PIN)'
        : (_isUpi ? 'e.g. username@okhdfcbank' : 'e.g. 1234 5678 9012 or ABCDE1234F');
    final nameLabel = _isPaymentCard
        ? 'Cardholder Name'
        : (_isUpi ? 'Account Holder Name' : 'Full Name on Document');
    final issuerLabel = _isPaymentCard
        ? 'Issuing Bank / Card Brand'
        : (_isUpi ? 'Linked App / Bank' : 'Issuing Country');
    final issuerHint = _isPaymentCard
        ? 'e.g. HDFC Bank, SBI, ICICI'
        : (_isUpi ? 'e.g. Google Pay, PhonePe, Paytm' : 'e.g. India');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isEditing ? 'Edit Item' : (_isPaymentCard ? 'Add Payment Card' : (_isUpi ? 'Add UPI ID' : 'Add ID Card')),
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
                // Quick 1-Tap Presets
                if (!isEditing) ...[
                  const Text(
                    'Quick Presets (1-Tap Selection)',
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
                      children: _quickPresets.map((preset) {
                        final isSelected = _documentType == preset['type'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ActionChip(
                            label: Text(preset['title']!),
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
                            onPressed: () => _applyQuickPreset(preset),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Banking Safety Alert Box (When storing Debit/Credit card)
                if (_isPaymentCard) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bank Security Rule: Never store CVV, ATM PIN, or Net Banking passwords. Only safe reference details (card nickname, last 4 digits, expiry) are kept.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF7A5800), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Document / Card Type Selector
                const Text(
                  'Record Type *',
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
                    prefixIcon: Icon(
                      _isPaymentCard ? Icons.credit_card_rounded : (_isUpi ? Icons.account_balance_wallet_rounded : Icons.badge_outlined),
                      color: AppColors.primary,
                    ),
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
                        if (_isPaymentCard || _isUpi) {
                          _subcategory = 'Finance';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Title Field
                Text(
                  _isPaymentCard ? 'Card Nickname / Title *' : 'Title *',
                  style: const TextStyle(
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
                    hintText: _isPaymentCard ? 'e.g. HDFC Millennia Debit Card' : 'e.g. Aadhaar Card, Passport',
                    prefixIcon: const Icon(Icons.title_rounded, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Number Field (Last 4 digits / UPI ID / ID Number)
                Text(
                  numberLabel,
                  style: const TextStyle(
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
                      return 'Please enter ${_isPaymentCard ? "last 4 digits" : (_isUpi ? "UPI ID" : "document number")}';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: numberHint,
                    prefixIcon: Icon(_isPaymentCard ? Icons.credit_card_outlined : Icons.pin_outlined, color: AppColors.textMutedNavy),
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

                // Full Name / Cardholder Name
                Text(
                  nameLabel,
                  style: const TextStyle(
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
                const SizedBox(height: AppSpacing.md),

                // Bank / Issuer / Issuing Country
                Text(
                  issuerLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _countryController,
                  decoration: InputDecoration(
                    hintText: issuerHint,
                    prefixIcon: Icon(_isPaymentCard ? Icons.account_balance_outlined : Icons.flag_outlined, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Expiry Date (or MM/YY for cards)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPaymentCard ? 'Card Expiry (MM/YY)' : 'Expiry Date',
                      style: const TextStyle(
                        color: AppColors.textPrimaryNavy,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (!_isPaymentCard)
                      Row(
                        children: [
                          const Text('No Expiry', style: TextStyle(fontSize: 12, color: AppColors.textMutedNavy)),
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
                const SizedBox(height: 6),
                TextFormField(
                  controller: _expiryDateController,
                  readOnly: !_isPaymentCard,
                  onTap: _isPaymentCard ? null : (_noExpiry ? null : () => _selectDate(context, _expiryDateController)),
                  decoration: InputDecoration(
                    hintText: _isPaymentCard ? 'e.g. 08/29' : (_noExpiry ? 'Does not expire' : 'Select expiry date'),
                    prefixIcon: const Icon(Icons.event_outlined, size: 18, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Notes Field
                const Text(
                  'Notes / Billing Details (Optional)',
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
                    hintText: _isPaymentCard
                        ? 'e.g. Salary account debit card, billing cycle date'
                        : 'Additional details or reminders...',
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Attachment (Front/Back photo or PDF)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Encrypted Document Scan (Optional)',
                          style: TextStyle(
                            color: AppColors.textPrimaryNavy,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Attach a photo or PDF scan encrypted on device',
                          style: TextStyle(color: AppColors.textMutedNavy, fontSize: 11),
                        ),
                        const SizedBox(height: 10),
                        if (_newPickedAttachment != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.attach_file_rounded, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${_newPickedAttachment!.name} (${_formatFileSize(_newPickedAttachmentSize)})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
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
                        ] else if (_existingAttachmentPath != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Scan attached (Encrypted on device)',
                                  style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 12),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _pickAttachment,
                                child: const Text('Replace', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ] else ...[
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.upload_file_rounded, size: 18),
                            label: const Text('Attach Scan / Photo'),
                            onPressed: _pickAttachment,
                          ),
                        ],
                      ],
                    ),
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
