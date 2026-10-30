import 'dart:convert';
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
  final _secPhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _secEmailController = TextEditingController();
  final _companyController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _addressController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  bool _isFavourite = false;
  String _selectedCategory = 'Personal';

  final List<String> _categories = [
    'Personal',
    'Work',
    'Family',
    'Emergency',
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
          category: VaultCategory.contacts,
        ),
      );
      if (item.id.isNotEmpty) {
        _nameController.text = item.title;
        _phoneController.text = item.phoneNumber ?? (item.details?.startsWith('+') == true ? item.details! : '');
        _secPhoneController.text = item.secondaryPhone ?? '';
        _emailController.text = item.email ?? item.username ?? '';
        _secEmailController.text = item.secondaryEmail ?? '';
        _companyController.text = item.company ?? '';
        _jobTitleController.text = item.jobTitle ?? '';
        _addressController.text = item.address ?? '';
        _birthdayController.text = item.birthday ?? '';
        _notesController.text = item.details != null && !item.details!.startsWith('+') ? item.details! : '';
        _tagsController.text = item.tags ?? '';
        if (item.subcategory != null && _categories.contains(item.subcategory)) {
          _selectedCategory = item.subcategory!;
        }
        _isFavourite = item.isFavourite;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _secPhoneController.dispose();
    _emailController.dispose();
    _secEmailController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _addressController.dispose();
    _birthdayController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1995, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
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
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final monthStr = months[picked.month - 1];
      setState(() {
        _birthdayController.text = '${picked.day} $monthStr ${picked.year}';
      });
    }
  }

  Future<void> _importVcfFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final content = utf8.decode(bytes, allowMalformed: true);
        _parseAndFillVCard(content);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact details loaded from ${file.name}!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not read contact file: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _parseAndFillVCard(String vcf) {
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
        } else if (_secPhoneController.text.isEmpty) {
          _secPhoneController.text = val;
        }
      } else if (line.startsWith('EMAIL') && line.contains(':')) {
        final val = line.split(':').last.trim();
        if (_emailController.text.isEmpty) {
          _emailController.text = val;
        } else if (_secEmailController.text.isEmpty) {
          _secEmailController.text = val;
        }
      } else if (line.startsWith('ORG:')) {
        _companyController.text = line.substring(4).replaceAll(';', ' ').trim();
      } else if (line.startsWith('TITLE:')) {
        _jobTitleController.text = line.substring(6).trim();
      } else if (line.startsWith('NOTE:')) {
        _notesController.text = line.substring(5).trim();
      } else if (line.startsWith('BDAY:')) {
        _birthdayController.text = line.substring(5).trim();
      } else if (line.startsWith('ADR') && line.contains(':')) {
        final val = line.split(':').last.replaceAll(';', ' ').trim();
        if (val.isNotEmpty) _addressController.text = val;
      }
    }
    setState(() {});
  }

  void _showVcfGuideDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.contact_phone_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Import from Mobile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to export contacts from your phone:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              '1. Open your phone\'s Contacts app (e.g. Google Contacts).\n'
              '2. Tap "Fix & manage" (or Settings) at the bottom.\n'
              '3. Tap "Export to file" and save as .vcf.\n'
              '4. Tap "Import Contact (.vcf)" below and select that file.\n\n'
              'All details will be imported instantly and stored 100% offline in your vault.',
              style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveContact() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final cleanTags = _tagsController.text
          .split(',')
          .map((t) => t.trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .join(',');

      await ref.read(vaultItemsProvider.notifier).saveContactItem(
            id: widget.itemId,
            fullName: _nameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            secondaryPhone: _secPhoneController.text.trim().isNotEmpty ? _secPhoneController.text.trim() : null,
            email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
            secondaryEmail: _secEmailController.text.trim().isNotEmpty ? _secEmailController.text.trim() : null,
            company: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
            jobTitle: _jobTitleController.text.trim().isNotEmpty ? _jobTitleController.text.trim() : null,
            address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
            birthday: _birthdayController.text.trim().isNotEmpty ? _birthdayController.text.trim() : null,
            notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
            category: _selectedCategory,
            tags: cleanTags.isNotEmpty ? cleanTags : null,
            isFavourite: _isFavourite,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.itemId != null ? 'Contact updated successfully' : 'Contact saved to vault',
          ),
          backgroundColor: AppColors.primary,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Import Banner from Phone
                if (!isEditing) ...[
                  Card(
                    elevation: 0,
                    color: AppColors.primaryLight.withAlpha(90),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: AppColors.primary.withAlpha(60)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_android_rounded, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Import from Mobile Device',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.textPrimaryNavy,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Auto-fill from .vcf export file',
                                  style: TextStyle(color: AppColors.textMutedNavy, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.primary),
                            tooltip: 'How to export contacts',
                            onPressed: _showVcfGuideDialog,
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: _importVcfFile,
                            child: const Text('Import .vcf', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Full Name
                const Text(
                  'Full Name *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryNavy,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Rahul Sharma',
                    prefixIcon: Icon(Icons.person_rounded, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Phone Numbers Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Primary Phone *',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '+91 98765 43210',
                              prefixIcon: Icon(Icons.phone_android_rounded, color: AppColors.textMutedNavy, size: 20),
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Enter phone number';
                              }
                              return null;
                            },
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
                            'Secondary Phone',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _secPhoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: '+91 91234 56789',
                              prefixIcon: Icon(Icons.phone_rounded, color: AppColors.textMutedNavy, size: 20),
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Emails Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Primary Email',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'user@example.com',
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.textMutedNavy, size: 20),
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            'Secondary Email',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _secEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'work@domain.com',
                              prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.textMutedNavy, size: 20),
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Work Row (Company & Job Title)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Company / Org',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _companyController,
                            decoration: const InputDecoration(
                              hintText: 'Acme Corp',
                              prefixIcon: Icon(Icons.business_rounded, color: AppColors.textMutedNavy, size: 20),
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            'Job Title',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _jobTitleController,
                            decoration: const InputDecoration(
                              hintText: 'Product Manager',
                              prefixIcon: Icon(Icons.work_outline_rounded, color: AppColors.textMutedNavy, size: 20),
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Address Field
                const Text(
                  'Address',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryNavy,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    hintText: '123 Marine Drive, Mumbai, MH, 400020',
                    prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Birthday & Category Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Birthday',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _birthdayController,
                            readOnly: true,
                            onTap: _selectBirthday,
                            decoration: InputDecoration(
                              hintText: 'Select Date',
                              prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.textMutedNavy, size: 20),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
                                onPressed: _selectBirthday,
                              ),
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            'Category',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryNavy,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: _categories.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(c, style: const TextStyle(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategory = val);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Tags Field
                const Text(
                  'Tags (comma separated)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryNavy,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    hintText: 'colleague, client, emergency',
                    prefixIcon: Icon(Icons.tag_rounded, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Notes Field
                const Text(
                  'Private Notes (Optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryNavy,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Additional details or private context...',
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Security Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Contacts are stored securely and privately on this device only. Zero external syncing.',
                          style: TextStyle(
                            color: AppColors.textPrimaryNavy,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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
