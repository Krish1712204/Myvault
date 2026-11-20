import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/security/clipboard_service.dart';
import '../../../../core/security/password_generator.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/letter_avatar.dart';
import '../../../../shared/widgets/detail_actions.dart';
import '../../data/vault_item_model.dart';

class PasswordDetailsScreen extends ConsumerStatefulWidget {
  final String itemId;

  const PasswordDetailsScreen({
    super.key,
    required this.itemId,
  });

  @override
  ConsumerState<PasswordDetailsScreen> createState() => _PasswordDetailsScreenState();
}

class _PasswordDetailsScreenState extends ConsumerState<PasswordDetailsScreen> {
  bool _showPassword = false;

  Future<void> _confirmDelete(BuildContext context, VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Password?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.title}" from your vault? This action cannot be undone.',
          style: TextStyle(color: AppColors.textPrimaryNavy),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMutedNavy)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final deleted = await ref.read(vaultItemsProvider.notifier).removeItem(item.id);
      if (!context.mounted) return;
      if (!deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete item. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.title} deleted from vault'),
          backgroundColor: AppColors.textPrimaryNavy,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(vaultItemsProvider);
    final matches = allItems.where((i) => i.id == widget.itemId).toList();

    if (matches.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('Password Details'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock_outlined, size: 48, color: AppColors.textMutedNavy),
              const SizedBox(height: 12),
              Text(
                'Password record not found or vault is locked',
                style: TextStyle(color: AppColors.textMutedNavy),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final item = matches.first;
    final passwordText = item.password ?? '';
    final strength = PasswordGenerator.calculateStrength(passwordText);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Password Details',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              item.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
              color: item.isFavourite ? Colors.amber : AppColors.textMutedNavy,
            ),
            tooltip: item.isFavourite ? 'Remove from Favourites' : 'Add to Favourites',
            onPressed: () async {
              final saved = await ref.read(vaultItemsProvider.notifier).toggleFavourite(item.id);
              if (!saved && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not update favourite. Please try again.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: [
            // Header card with Brand Logo
            Center(
              child: Column(
                children: [
                  LetterAvatar(name: item.title, size: 64),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: TextStyle(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subcategory ?? 'Website',
                    style: TextStyle(
                      color: AppColors.textMutedNavy,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Credentials Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Website URL
                    _buildField(
                      label: 'Website URL',
                      value: (item.url != null && item.url!.isNotEmpty) ? item.url! : 'Not specified',
                      icon: Icons.language_rounded,
                      onCopy: (item.url != null && item.url!.isNotEmpty)
                          ? () => ClipboardService.copyPublic(
                                context: context,
                                text: item.url!,
                                label: 'Website URL',
                              )
                          : null,
                    ),
                    Divider(color: AppColors.border, height: 24),
                    // Username / Email
                    _buildField(
                      label: 'Username / Email',
                      value: (item.username != null && item.username!.isNotEmpty) ? item.username! : item.subtitle,
                      icon: Icons.person_outline_rounded,
                      onCopy: (item.username != null && item.username!.isNotEmpty)
                          ? () => ClipboardService.copyPublic(
                                context: context,
                                text: item.username!,
                                label: 'Username',
                              )
                          : null,
                    ),
                    Divider(color: AppColors.border, height: 24),
                    // Password Field with Eye Toggle and Auto-Clear Copy
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lock_outline_rounded, color: AppColors.textMutedNavy, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Password',
                                style: TextStyle(
                                  color: AppColors.textMutedNavy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _showPassword ? passwordText : '••••••••••••••••',
                                style: TextStyle(
                                  color: AppColors.textPrimaryNavy,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMutedNavy,
                            size: 20,
                          ),
                          tooltip: _showPassword ? 'Hide Password' : 'Show Password',
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                          tooltip: 'Copy with Auto-Clear',
                          onPressed: () => ClipboardService.copySensitive(
                            context: context,
                            text: passwordText,
                            label: 'Password',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Password Strength Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Strength',
                          style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12),
                        ),
                        Text(
                          strength.label,
                          style: TextStyle(
                            color: strength.color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: strength.score,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(strength.color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Category Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _buildMetaRow('Category', item.subcategory ?? 'Website'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Edit and Delete Buttons
            DetailActions(
              onDelete: () => _confirmDelete(context, item),
              onEdit: () => context.push('/edit-password/${item.id}'),
              editLabel: 'Edit',
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textMutedNavy, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMutedNavy,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimaryNavy,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
            onPressed: onCopy,
          ),
      ],
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMutedNavy,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: AppColors.textPrimaryNavy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
