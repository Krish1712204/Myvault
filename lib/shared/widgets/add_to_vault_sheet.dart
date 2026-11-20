import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../features/vault_items/data/vault_item_model.dart';
import '../navigation/item_routes.dart';
import 'pressable_scale.dart';

const _descriptions = {
  VaultCategory.passwords: 'Logins & apps',
  VaultCategory.idCards: 'Aadhaar, PAN, passport',
  VaultCategory.documents: 'PDFs & files',
  VaultCategory.photos: 'Private images',
  VaultCategory.notes: 'Secure notes',
  VaultCategory.contacts: 'People & numbers',
};

/// Bottom sheet listing every kind of item that can be added to the vault.
Future<void> showAddToVaultSheet(BuildContext context) {
  return showModalBottomSheet(
        // Above the bottom navigation bar, not inside the current tab.
    useRootNavigator: true,
context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final textPrimary = AppColors.textPrimaryNavy;

      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.sheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Add to Vault',
                style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
              const SizedBox(height: 2),
              Text(
                'Everything is encrypted before it is saved.',
                style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
              ),
              const SizedBox(height: 18),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.92,
                children: [
                  for (final (i, category) in VaultCategory.values.indexed)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 320 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Opacity(
                        opacity: t,
                        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
                      ),
                      child: _AddTile(category: category, isDark: isDark, textPrimary: textPrimary, sheetContext: sheetContext),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AddTile extends StatelessWidget {
  final VaultCategory category;
  final bool isDark;
  final Color textPrimary;
  final BuildContext sheetContext;

  const _AddTile({
    required this.category,
    required this.isDark,
    required this.textPrimary,
    required this.sheetContext,
  });

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category);
    return PressableScale(
      onTap: () {
        final router = GoRouter.of(sheetContext);
        Navigator.pop(sheetContext);
        router.push(addRouteFor(category));
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : style.background.withAlpha(140),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: style.color.withAlpha(isDark ? 70 : 35)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: style.gradient,
                ),
                boxShadow: [
                  BoxShadow(color: style.color.withAlpha(70), blurRadius: 12, offset: const Offset(0, 5)),
                ],
              ),
              child: Icon(style.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              category.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _descriptions[category]!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
