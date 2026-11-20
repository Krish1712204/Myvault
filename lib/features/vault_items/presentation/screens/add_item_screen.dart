import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/security/password_generator.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/vault_form_kit.dart';
import '../widgets/password_generator_sheet.dart';
import '../../data/vault_item_model.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const AddItemScreen({
    super.key,
    this.itemId,
  });

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  /// The item being edited; its notes (not shown in this form) are kept on save.
  VaultItem? _existing;
  bool _initialized = false;
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _isFavourite = false;
  String _selectedCategory = 'Social';
  PasswordStrength _strength = PasswordStrength.weak;

  static const List<String> _categories = [
    'Social',
    'Email',
    'Apps',
    'Finance',
    'Work',
    'Shopping',
    'Personal',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final text = _passwordController.text;
    final newStrength = PasswordGenerator.calculateStrength(text);
    if (_strength != newStrength) {
      setState(() => _strength = newStrength);
    }
  }

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
          category: VaultCategory.passwords,
        ),
      );
      if (item.id.isNotEmpty) {
        _existing = item;
        _nameController.text = item.title;
        _urlController.text = item.url ?? '';
        _usernameController.text = item.username ?? '';
        _passwordController.text = item.password ?? '';
        _selectedCategory = _categories.contains(item.subcategory) ? item.subcategory! : 'Social';
        _isFavourite = item.isFavourite;
        _strength = PasswordGenerator.calculateStrength(item.password ?? '');
      }
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    if (_isSaving) return;

    final title = _nameController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an App / Website Name (e.g. Instagram)')),
      );
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final finalUrl = _urlController.text.trim();
      await ref.read(vaultItemsProvider.notifier).savePasswordItem(
            id: widget.itemId,
            title: title,
            websiteUrl: finalUrl.isNotEmpty ? finalUrl : null,
            username: _usernameController.text.trim(),
            password: password,
            subcategory: _selectedCategory,
            notes: _existing?.details,
            isFavourite: _isFavourite,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.itemId != null ? '$title updated successfully!' : '$title saved to vault!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save item. Please verify vault is unlocked.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _generatePassword() async {
    final generated = await PasswordGeneratorSheet.show(context);
    if (generated == null || generated.isEmpty || !mounted) return;
    setState(() {
      _passwordController.text = generated;
      _obscurePassword = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.itemId != null;
    final hasPassword = _passwordController.text.isNotEmpty;

    return VaultFormScaffold(
      category: VaultCategory.passwords,
      title: isEditing ? 'Edit Password' : 'New Password',
      subtitle: 'Login details for an app or website',
      isFavourite: _isFavourite,
      onFavouriteChanged: (v) => setState(() => _isFavourite = v),
      saving: _isSaving,
      onSave: _saveItem,
      saveLabel: isEditing ? 'Save Changes' : 'Save Password',
      children: [
        FormSectionCard(
          title: 'Account',
          icon: Icons.apps_rounded,
          children: [
            LabeledField(
              label: 'App / Website name',
              required: true,
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'e.g. Instagram, Gmail, HDFC',
                  prefixIcon: Icon(Icons.apps_rounded),
                ),
              ),
            ),
            LabeledField(
              label: 'Username or email',
              child: TextField(
                controller: _usernameController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '@handle or you@gmail.com',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
              ),
            ),
            LabeledField(
              label: 'Website',
              child: TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'instagram.com',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
            ),
          ],
        ),
        FormSectionCard(
          title: 'Password',
          icon: Icons.lock_rounded,
          children: [
            LabeledField(
              label: 'Password',
              required: true,
              trailing: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: hasPassword
                    ? Container(
                        key: ValueKey(_strength),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: _strength.color.withAlpha(35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _strength.label,
                          style: TextStyle(color: _strength.color, fontWeight: FontWeight.w800, fontSize: 11.5),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              child: TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.4),
                decoration: InputDecoration(
                  hintText: 'Enter or generate a password',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Show' : 'Hide',
                    icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
            ),
            if (hasPassword)
              TweenAnimationBuilder<double>(
                tween: Tween(end: _strength.score),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 6,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: value >= (i + 1) * 0.25 - 0.01 ? _strength.color : AppColors.border,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: _generatePassword,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.categoryPasswords),
              label: const Text(
                'Generate a strong password',
                style: TextStyle(color: AppColors.categoryPasswords, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.categoryPasswords.withAlpha(90)),
                backgroundColor: AppColors.categoryPasswords.withAlpha(12),
                padding: const EdgeInsets.symmetric(vertical: 13),
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
              color: AppColors.categoryPasswords,
              onSelected: (c) => setState(() => _selectedCategory = c),
            ),
          ],
        ),
      ],
    );
  }
}
