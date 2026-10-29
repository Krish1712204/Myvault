import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../data/vault_item_model.dart';

class AddNoteScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const AddNoteScreen({
    super.key,
    this.itemId,
  });

  @override
  ConsumerState<AddNoteScreen> createState() => _AddNoteScreenState();
}

class _AddNoteScreenState extends ConsumerState<AddNoteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  bool _isFavourite = false;
  String _selectedCategory = 'Personal';

  final List<String> _categories = [
    'Personal',
    'Work',
    'Ideas',
    'Finance',
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
          category: VaultCategory.notes,
        ),
      );
      if (item.id.isNotEmpty) {
        _titleController.text = item.title;
        _contentController.text = item.details ?? '';
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
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final cleanTags = _tagsController.text
          .split(',')
          .map((t) => t.trim().replaceAll('#', ''))
          .where((t) => t.isNotEmpty)
          .join(',');

      await ref.read(vaultItemsProvider.notifier).saveNoteItem(
            id: widget.itemId,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            category: _selectedCategory,
            tags: cleanTags.isNotEmpty ? cleanTags : null,
            isFavourite: _isFavourite,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.itemId != null ? 'Note updated successfully' : 'Note saved to vault',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save note: $e'),
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
          isEditing ? 'Edit Note' : 'Add Note',
          style: const TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _saveNote,
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
                // Title Field
                const Text(
                  'Title *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryNavy,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Project Plan or Meeting Summary',
                    prefixIcon: Icon(Icons.title_rounded, color: AppColors.textMutedNavy),
                    fillColor: Colors.white,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Category & Tags Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Dropdown
                    Expanded(
                      flex: 4,
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
                    const SizedBox(width: 12),
                    // Tags Input
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              hintText: 'work, ideas, 2026',
                              prefixIcon: Icon(Icons.tag_rounded, color: AppColors.textMutedNavy, size: 20),
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

                // Note Content Field
                const Text(
                  'Note Content *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryNavy,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _contentController,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    hintText: 'Write your private note here...',
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Note content cannot be empty';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.md),

                // Mark as Favorite Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Mark as Favourite',
                            style: TextStyle(
                              color: AppColors.textPrimaryNavy,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isFavourite,
                        activeThumbColor: AppColors.primary,
                        onChanged: (val) => setState(() => _isFavourite = val),
                      ),
                    ],
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
                          'Notes are encrypted at rest with SQLCipher AES-256 in app-private device storage.',
                          style: TextStyle(
                            color: AppColors.textPrimaryNavy,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
