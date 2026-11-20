import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/bold_text.dart';
import '../../../../shared/widgets/vault_form_kit.dart';
import '../../../../core/ui/user_message.dart';
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
  final _contentController = BoldTextEditingController();

  /// The item being edited; its tags and colour (not shown in this form) are kept on save.
  VaultItem? _existing;
  bool _initialized = false;
  bool _isSaving = false;
  bool _isFavourite = false;
  String _selectedCategory = 'Personal';

  final List<String> _categories = [
    'Personal',
    'Work',
    'Ideas',
    'Finance',
    'Recovery Codes',
    'Security',
    'Medical',
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
        _existing = item;
        _titleController.text = item.title;
        _contentController.text = item.details ?? '';
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
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(vaultItemsProvider.notifier).saveNoteItem(
            id: widget.itemId,
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            category: _selectedCategory,
            colorTag: _existing?.colorTag,
            tags: _existing?.tags,
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
          content: Text('Could not save the note. ${userMessage(e)}'),
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
    'Ideas': Icons.lightbulb_rounded,
    'Finance': Icons.account_balance_wallet_rounded,
    'Recovery Codes': Icons.vpn_key_rounded,
    'Security': Icons.shield_rounded,
    'Medical': Icons.medical_services_rounded,
    'Other': Icons.more_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemId != null;

    return Form(
      key: _formKey,
      child: VaultFormScaffold(
        category: VaultCategory.notes,
        title: isEditing ? 'Edit Note' : 'New Note',
        subtitle: 'Private notes, codes and ideas',
        isFavourite: _isFavourite,
        onFavouriteChanged: (v) => setState(() => _isFavourite = v),
        saving: _isSaving,
        onSave: _saveNote,
        saveLabel: isEditing ? 'Save Changes' : 'Save Note',
        children: [
          FormSectionCard(
            title: 'Note',
            icon: Icons.edit_note_rounded,
            children: [
              LabeledField(
                label: 'Title',
                required: true,
                child: TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  // Note titles are always bold.
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'e.g. 2FA recovery keys, Project plan',
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter a title' : null,
                ),
              ),
              LabeledField(
                label: 'Content',
                required: true,
                trailing: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _contentController,
                  builder: (context, value, _) {
                    final words = stripBoldMarkers(value.text).trim().isEmpty ? 0 : stripBoldMarkers(value.text).trim().split(RegExp(r'\s+')).length;
                    return Text(
                      '$words word${words == 1 ? '' : 's'}',
                      style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12, fontWeight: FontWeight.w600),
                    );
                  },
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormatBar(onBold: () {
                      _contentController.toggleBold();
                      HapticFeedback.selectionClick();
                    }),
                    const SizedBox(height: 8),
                    TextFormField(
                  controller: _contentController,
                  minLines: 8,
                  maxLines: 16,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'Write your private note, codes or thoughts here…',
                    alignLabelWithHint: true,
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter note content' : null,
                ),
                  ],
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
                color: AppColors.categoryNotes,
                onSelected: (c) => setState(() => _selectedCategory = c),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small formatting toolbar above the note editor.
class _FormatBar extends StatelessWidget {
  final VoidCallback onBold;

  const _FormatBar({required this.onBold});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Bold (select text first)',
          child: Material(
            color: AppColors.categoryNotes.withAlpha(28),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onBold,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.format_bold_rounded, size: 20, color: AppColors.categoryNotes),
                    SizedBox(width: 4),
                    Text(
                      'Bold',
                      style: TextStyle(color: AppColors.categoryNotes, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Select words, then tap Bold',
            style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
