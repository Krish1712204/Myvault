import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/security/password_generator.dart';
import '../../../../shared/state/vault_state_provider.dart';
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
            notes: null,
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
          isEditing ? 'Edit Password' : 'Save Password',
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
            padding: const EdgeInsets.only(right: 14.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: [
            // 1. Title / App Name
            const Text(
              'App / Website Name *',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Instagram, Gmail, Facebook',
                prefixIcon: Icon(Icons.apps_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. User ID / Username / Email
            const Text(
              'User ID / Username / Email',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                hintText: 'e.g. @yourhandle or user@gmail.com',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMutedNavy),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Password
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Password *',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
                ),
                if (_passwordController.text.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _strength.color.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _strength.label,
                      style: TextStyle(
                        color: _strength.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMutedNavy),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textMutedNavy,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),

            // Strength bar
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _strength.score,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(_strength.color),
                  minHeight: 4,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // 4. Website URL (Optional)
            const Text(
              'Website URL (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'e.g. instagram.com (optional)',
                prefixIcon: Icon(Icons.link_rounded, color: AppColors.textMutedNavy),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 5. Category selector
            const Text(
              'Category',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                  items: _categories
                      .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
