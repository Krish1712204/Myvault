import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
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
  final _urlController = TextEditingController(text: 'https://');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _notesController = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  bool _obscurePassword = true;
  bool _isFavourite = false;
  String _selectedCategory = 'Website';
  VaultCategory _mainCategory = VaultCategory.passwords;

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
        _urlController.text = (item.url != null && item.url!.isNotEmpty) ? item.url! : 'https://';
        _usernameController.text = item.username ?? '';
        _passwordController.text = item.password ?? '';
        _notesController.text = item.details ?? '';
        _selectedCategory = item.subcategory ?? 'Website';
        _mainCategory = item.category;
        _isFavourite = item.isFavourite;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _generateStrongPassword() async {
    final generated = await PasswordGeneratorSheet.show(context);
    if (generated != null && generated.isNotEmpty) {
      setState(() {
        _passwordController.text = generated;
        _obscurePassword = false;
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
        const SnackBar(content: Text('Please enter an Item / App Name')),
      );
      return;
    }

    final password = _passwordController.text;
    if (password.isEmpty && _mainCategory == VaultCategory.passwords) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or generate a password')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (_mainCategory == VaultCategory.passwords) {
        await ref.read(vaultItemsProvider.notifier).savePasswordItem(
              id: widget.itemId,
              title: title,
              websiteUrl: _urlController.text.trim(),
              username: _usernameController.text.trim(),
              password: password,
              subcategory: _selectedCategory,
              notes: _notesController.text.trim(),
              isFavourite: _isFavourite,
            );
      } else {
        final newItem = VaultItem(
          id: widget.itemId ?? 'custom_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          subtitle: _usernameController.text.isNotEmpty ? _usernameController.text : _selectedCategory,
          category: _mainCategory,
          url: _urlController.text,
          username: _usernameController.text,
          password: _passwordController.text,
          details: _notesController.text,
          subcategory: _selectedCategory,
          isFavourite: _isFavourite,
          date: 'Just now',
        );
        await ref.read(vaultItemsProvider.notifier).addItem(newItem);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.itemId != null ? '$title updated successfully!' : '$title added to your vault!'),
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
    final screenTitle = isEditing
        ? 'Edit Password'
        : (_mainCategory == VaultCategory.passwords ? 'Add Password' : 'Add Item');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          screenTitle,
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
            // Category selector (hidden in editing to preserve item type)
            if (!isEditing) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<VaultCategory>(
                    value: _mainCategory,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                    items: VaultCategory.values.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text('Category: ${c.displayName}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _mainCategory = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            // Item Name
            const Text('Website / App Name *', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Google',
                prefixIcon: Icon(Icons.language_rounded, color: AppColors.textMutedNavy),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Website URL
            const Text('Website URL', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy)),
            const SizedBox(height: 6),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'https://',
                prefixIcon: Icon(Icons.link_rounded, color: AppColors.textMutedNavy),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Username / Email
            const Text('Username / Email', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy)),
            const SizedBox(height: 6),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                hintText: 'Enter username or email',
                prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textMutedNavy),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Password
            const Text('Password *', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy)),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMutedNavy),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
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
                    Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
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
            // Subcategory Dropdown
            const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy)),
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
                  items: ['Website', 'Apps', 'Finance', 'Government', 'Personal', 'Other']
                      .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Notes
            const Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Add any notes...',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Mark as Favourite Switch Card
            Card(
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
