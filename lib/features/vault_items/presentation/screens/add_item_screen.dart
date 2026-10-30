import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/security/password_generator.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../data/vault_item_model.dart';
import '../widgets/password_generator_sheet.dart';

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
  final _notesController = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _isFavourite = false;
  String _selectedCategory = 'Social';
  PasswordStrength _strength = PasswordStrength.weak;

  static const List<Map<String, String>> _popularApps = [
    {'name': 'Instagram', 'cat': 'Social', 'url': 'https://instagram.com'},
    {'name': 'Gmail / Google', 'cat': 'Email', 'url': 'https://google.com'},
    {'name': 'Facebook', 'cat': 'Social', 'url': 'https://facebook.com'},
    {'name': 'X (Twitter)', 'cat': 'Social', 'url': 'https://x.com'},
    {'name': 'LinkedIn', 'cat': 'Work', 'url': 'https://linkedin.com'},
    {'name': 'Telegram', 'cat': 'Social', 'url': 'https://telegram.org'},
    {'name': 'Discord', 'cat': 'Social', 'url': 'https://discord.com'},
    {'name': 'GitHub', 'cat': 'Work', 'url': 'https://github.com'},
    {'name': 'Amazon', 'cat': 'Shopping', 'url': 'https://amazon.in'},
    {'name': 'Flipkart', 'cat': 'Shopping', 'url': 'https://flipkart.com'},
    {'name': 'Net Banking', 'cat': 'Finance', 'url': ''},
    {'name': 'Company Creds', 'cat': 'Work', 'url': ''},
  ];

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
        _notesController.text = item.details ?? '';
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
    _notesController.dispose();
    super.dispose();
  }

  void _applyQuickApp(Map<String, String> app) {
    setState(() {
      _nameController.text = app['name']!;
      if (_categories.contains(app['cat'])) {
        _selectedCategory = app['cat']!;
      }
      if (_urlController.text.trim().isEmpty && (app['url']?.isNotEmpty ?? false)) {
        _urlController.text = app['url']!;
      }
    });
  }

  Future<void> _generateStrongPassword() async {
    final generated = await PasswordGeneratorSheet.show(context);
    if (generated != null && generated.isNotEmpty) {
      setState(() {
        _passwordController.text = generated;
        _obscurePassword = false;
        _strength = PasswordGenerator.calculateStrength(generated);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Strong password applied!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
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
        const SnackBar(content: Text('Please enter or generate a password')),
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
            notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
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
            // Quick 1-Tap App Suggestions (Shown on add new)
            if (!isEditing) ...[
              const Text(
                'Quick Presets (1-Tap Fill)',
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
                  children: _popularApps.map((app) {
                    final isSelected = _nameController.text.trim().toLowerCase() == app['name']!.toLowerCase();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        label: Text(app['name']!),
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
                        onPressed: () => _applyQuickApp(app),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

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

            const SizedBox(height: AppSpacing.sm),

            // Generate Strong Password button
            InkWell(
              onTap: _generateStrongPassword,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(50)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_fix_high_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Generate Strong Password',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 14),
                  ],
                ),
              ),
            ),
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
            const SizedBox(height: AppSpacing.md),

            // 6. Notes (Optional)
            const Text(
              'Notes (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Security question hints, recovery notes, etc.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Mark as Favourite
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Mark as Favourite',
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimaryNavy),
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
    );
  }
}
