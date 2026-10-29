import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../vault_items/data/vault_item_model.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(categoryCountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Text(
          'Categories',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: VaultCategory.values.map((category) {
            final info = _getCategoryVisuals(category);
            final count = counts[category] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => context.push('/category/${category.keyName}'),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: info.backgroundColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(info.icon, color: info.color, size: 24),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.displayName,
                              style: const TextStyle(
                                color: AppColors.textPrimaryNavy,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count items',
                              style: const TextStyle(
                                color: AppColors.textMutedNavy,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: AppColors.textMutedNavy,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  _CategoryVisuals _getCategoryVisuals(VaultCategory category) {
    switch (category) {
      case VaultCategory.passwords:
        return _CategoryVisuals(
          icon: Icons.key_rounded,
          color: AppColors.categoryPasswords,
          backgroundColor: AppColors.categoryPasswordsBg,
        );
      case VaultCategory.idCards:
        return _CategoryVisuals(
          icon: Icons.badge_outlined,
          color: AppColors.categoryIdCards,
          backgroundColor: AppColors.categoryIdCardsBg,
        );
      case VaultCategory.documents:
        return _CategoryVisuals(
          icon: Icons.description_outlined,
          color: AppColors.categoryDocuments,
          backgroundColor: AppColors.categoryDocumentsBg,
        );
      case VaultCategory.photos:
        return _CategoryVisuals(
          icon: Icons.image_outlined,
          color: AppColors.categoryPhotos,
          backgroundColor: AppColors.categoryPhotosBg,
        );
      case VaultCategory.notes:
        return _CategoryVisuals(
          icon: Icons.sticky_note_2_outlined,
          color: AppColors.categoryNotes,
          backgroundColor: AppColors.categoryNotesBg,
        );
      case VaultCategory.contacts:
        return _CategoryVisuals(
          icon: Icons.person_outline_rounded,
          color: AppColors.categoryContacts,
          backgroundColor: AppColors.categoryContactsBg,
        );
    }
  }
}

class _CategoryVisuals {
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  _CategoryVisuals({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

