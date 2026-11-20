import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../features/vault_items/data/vault_item_model.dart';

/// Visual identity of a vault category, shared by dashboard cards, lists and forms.
class CategoryStyle {
  final IconData icon;
  final Color color;
  final Color background;
  final List<Color> gradient;

  const CategoryStyle({
    required this.icon,
    required this.color,
    required this.background,
    required this.gradient,
  });

  static CategoryStyle of(VaultCategory category) {
    switch (category) {
      case VaultCategory.passwords:
        return CategoryStyle(
          icon: Icons.key_rounded,
          color: AppColors.categoryPasswords,
          background: AppColors.categoryPasswordsBg,
          gradient: AppColors.gradientBlue,
        );
      case VaultCategory.idCards:
        return CategoryStyle(
          icon: Icons.badge_rounded,
          color: AppColors.categoryIdCards,
          background: AppColors.categoryIdCardsBg,
          gradient: AppColors.gradientAmber,
        );
      case VaultCategory.documents:
        return CategoryStyle(
          icon: Icons.description_rounded,
          color: AppColors.categoryDocuments,
          background: AppColors.categoryDocumentsBg,
          gradient: AppColors.gradientRose,
        );
      case VaultCategory.photos:
        return CategoryStyle(
          icon: Icons.photo_library_rounded,
          color: AppColors.categoryPhotos,
          background: AppColors.categoryPhotosBg,
          gradient: AppColors.gradientGreen,
        );
      case VaultCategory.notes:
        return CategoryStyle(
          icon: Icons.sticky_note_2_rounded,
          color: AppColors.categoryNotes,
          background: AppColors.categoryNotesBg,
          gradient: AppColors.gradientPurple,
        );
      case VaultCategory.contacts:
        return CategoryStyle(
          icon: Icons.person_rounded,
          color: AppColors.categoryContacts,
          background: AppColors.categoryContactsBg,
          gradient: AppColors.gradientSky,
        );
    }
  }
}

/// Route that opens the "add" form for a category.
String addRouteFor(VaultCategory category) {
  switch (category) {
    case VaultCategory.passwords:
      return '/add-item';
    case VaultCategory.idCards:
      return '/add-id';
    case VaultCategory.documents:
      return '/add-document';
    case VaultCategory.photos:
      return '/add-document?type=photos';
    case VaultCategory.notes:
      return '/add-note';
    case VaultCategory.contacts:
      return '/add-contact';
  }
}

/// Route that opens an item's detail screen.
String detailRouteFor(VaultItem item) {
  switch (item.category) {
    case VaultCategory.passwords:
      return '/password-details/${item.id}';
    case VaultCategory.idCards:
      return '/id-details/${item.id}';
    case VaultCategory.documents:
    case VaultCategory.photos:
      return '/document-details/${item.id}';
    case VaultCategory.notes:
      return '/note-details/${item.id}';
    case VaultCategory.contacts:
      return '/contact-details/${item.id}';
  }
}
