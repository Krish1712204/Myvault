import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../vault_items/data/vault_item_model.dart';

import '../../../../core/security/clipboard_service.dart';

class CategoryItemsScreen extends ConsumerStatefulWidget {
  final String categoryKey;

  const CategoryItemsScreen({
    super.key,
    required this.categoryKey,
  });

  @override
  ConsumerState<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends ConsumerState<CategoryItemsScreen> {
  final _searchController = TextEditingController();
  String _selectedSubcategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to permanently delete "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(vaultItemsProvider.notifier).removeItem(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = VaultCategory.fromKey(widget.categoryKey);
    final items = ref.watch(itemsByCategoryProvider(category));
    final query = _searchController.text.trim().toLowerCase();

    final subcategories = _getSubcategoriesFor(category);

    final filteredItems = items.where((item) {
      if (_selectedSubcategory != 'All') {
        final itemSub = item.subcategory?.toLowerCase() ?? '';
        final selSub = _selectedSubcategory.toLowerCase();
        final matchesSub = itemSub == selSub ||
            (selSub == 'websites' && itemSub == 'website') ||
            (selSub == 'website' && itemSub == 'websites') ||
            (selSub == 'apps' && itemSub == 'app');
        if (!matchesSub) return false;
      }
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query) ||
          (item.url != null && item.url!.toLowerCase().contains(query)) ||
          (item.username != null && item.username!.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category.displayName,
              style: const TextStyle(
                color: AppColors.textPrimaryNavy,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${items.length} items',
              style: const TextStyle(
                color: AppColors.textMutedNavy,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
            onPressed: () => context.push('/add-item'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search ${category.displayName.toLowerCase()}...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMutedNavy),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppColors.textMutedNavy),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                  if (subcategories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: subcategories.map((sub) {
                          final isSelected = _selectedSubcategory == sub;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(sub),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedSubcategory = sub),
                              selectedColor: AppColors.primary,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimaryNavy,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                ),
                              ),
                              showCheckmark: false,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        'No ${category.displayName.toLowerCase()} found',
                        style: const TextStyle(color: AppColors.textMutedNavy),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: () {
                              if (category == VaultCategory.passwords) {
                                context.push('/password-details/${item.id}');
                              } else {
                                _showItemDetailsDialog(context, item);
                              }
                            },
                            leading: _buildItemAvatar(item),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                color: AppColors.textPrimaryNavy,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: Text(
                              item.subtitle,
                              style: const TextStyle(
                                color: AppColors.textMutedNavy,
                                fontSize: 13,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    item.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: item.isFavourite ? Colors.amber : AppColors.textMutedNavy,
                                    size: 22,
                                  ),
                                  onPressed: () {
                                    ref.read(vaultItemsProvider.notifier).toggleFavourite(item.id);
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMutedNavy, size: 20),
                                  onSelected: (action) {
                                    if (action == 'view') {
                                      if (category == VaultCategory.passwords) {
                                        context.push('/password-details/${item.id}');
                                      } else {
                                        _showItemDetailsDialog(context, item);
                                      }
                                    } else if (action == 'edit') {
                                      context.push(category == VaultCategory.passwords
                                          ? '/edit-password/${item.id}'
                                          : '/add-item');
                                    } else if (action == 'delete') {
                                      _confirmDelete(context, item);
                                    } else if (action == 'copy') {
                                      if (category == VaultCategory.passwords && item.password != null) {
                                        ClipboardService.copySensitive(
                                          context: context,
                                          text: item.password!,
                                          label: 'Password',
                                        );
                                      } else {
                                        ClipboardService.copyPublic(
                                          context: context,
                                          text: item.username ?? item.subtitle,
                                          label: 'Username',
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'view', child: Text('View Details')),
                                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    const PopupMenuItem(value: 'copy', child: Text('Copy Password')),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemAvatar(VaultItem item) {
    if (item.category == VaultCategory.passwords) {
      Color bg = AppColors.primaryLight;
      Color textCol = AppColors.primary;
      String letter = item.title.isNotEmpty ? item.title[0].toUpperCase() : 'P';
      if (item.title == 'Google') {
        bg = const Color(0xFFEA4335).withAlpha(30);
        textCol = const Color(0xFFEA4335);
      } else if (item.title == 'GitHub') {
        bg = const Color(0xFF24292E).withAlpha(30);
        textCol = const Color(0xFF24292E);
      } else if (item.title == 'Amazon') {
        bg = const Color(0xFFFF9900).withAlpha(30);
        textCol = const Color(0xFFFF9900);
      } else if (item.title == 'Netflix') {
        bg = const Color(0xFFE50914).withAlpha(30);
        textCol = const Color(0xFFE50914);
      }

      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: textCol,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    IconData icon = Icons.lock_outline_rounded;
    Color color = AppColors.primary;
    Color bg = AppColors.primaryLight;

    if (item.category == VaultCategory.idCards) {
      icon = Icons.badge_outlined;
      color = AppColors.categoryIdCards;
      bg = AppColors.categoryIdCardsBg;
    } else if (item.category == VaultCategory.documents) {
      icon = Icons.picture_as_pdf_rounded;
      color = AppColors.categoryDocuments;
      bg = AppColors.categoryDocumentsBg;
    } else if (item.category == VaultCategory.photos) {
      icon = Icons.image_rounded;
      color = AppColors.categoryPhotos;
      bg = AppColors.categoryPhotosBg;
    } else if (item.category == VaultCategory.notes) {
      icon = Icons.sticky_note_2_rounded;
      color = AppColors.categoryNotes;
      bg = AppColors.categoryNotesBg;
    } else if (item.category == VaultCategory.contacts) {
      icon = Icons.person_rounded;
      color = AppColors.categoryContacts;
      bg = AppColors.categoryContactsBg;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  List<String> _getSubcategoriesFor(VaultCategory category) {
    switch (category) {
      case VaultCategory.passwords:
        return ['All', 'Websites', 'Apps', 'Finance', 'Other'];
      case VaultCategory.idCards:
        return ['All', 'Government', 'Personal', 'Work'];
      case VaultCategory.documents:
        return ['All', 'PDF', 'Images', 'Others'];
      default:
        return [];
    }
  }

  void _showItemDetailsDialog(BuildContext context, VaultItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            _buildItemAvatar(item),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subtitle: ${item.subtitle}', style: const TextStyle(color: AppColors.textSecondaryNavy)),
            if (item.details != null) ...[
              const SizedBox(height: 8),
              Text('Details: ${item.details}', style: const TextStyle(color: AppColors.textMutedNavy)),
            ],
            const SizedBox(height: 8),
            Text('Date: ${item.date}', style: const TextStyle(color: AppColors.textMutedNavy, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

