import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../vault_items/data/vault_item_model.dart';

class CategoryGridCard extends StatelessWidget {
  final VaultCategory category;
  final int count;

  const CategoryGridCard({
    super.key,
    required this.category,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final info = _getCategoryVisuals(category);

    return InkWell(
      onTap: () => context.push('/category/${category.keyName}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: info.color.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vibrant Top Category Accent Bar
              Container(
                height: 4.5,
                width: double.infinity,
                color: info.color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: info.backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          info.icon,
                          color: info.color,
                          size: 22,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimaryNavy,
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$count items',
                            style: const TextStyle(
                              color: AppColors.textMutedNavy,
                              fontSize: 12,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

