import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/navigation/item_routes.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../vault_items/data/vault_item_model.dart';

/// Dashboard category card: gradient icon, animated count, the latest item, and a quick "+".
class CategoryTile extends StatelessWidget {
  final VaultCategory category;
  final int count;
  final String? latestTitle;

  const CategoryTile({
    super.key,
    required this.category,
    required this.count,
    this.latestTitle,
  });

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = AppColors.surface;
    final textPrimary = AppColors.textPrimaryNavy;

    return PressableScale(
      onTap: () => context.push('/category/${category.keyName}'),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? AppColors.darkBorder : style.color.withAlpha(28)),
          boxShadow: [
            BoxShadow(color: style.color.withAlpha(isDark ? 30 : 26), blurRadius: 22, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Soft colour bloom in the corner
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      style.color.withAlpha(isDark ? 55 : 38),
                      style.color.withAlpha(0),
                    ]),
                  ),
                ),
              ),
              // Watermark icon
              Positioned(
                right: -14,
                bottom: -16,
                child: Transform.rotate(
                  angle: -0.25,
                  child: Icon(style.icon, size: 92, color: style.color.withAlpha(isDark ? 26 : 18)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: style.gradient,
                            ),
                            boxShadow: [
                              BoxShadow(color: style.color.withAlpha(80), blurRadius: 12, offset: const Offset(0, 5)),
                            ],
                          ),
                          child: Icon(style.icon, color: Colors.white, size: 22),
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: 'Add to ${category.displayName}',
                          child: PressableScale(
                            pressedScale: 0.85,
                            onTap: () => context.push(addRouteFor(category)),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: style.color.withAlpha(isDark ? 50 : 24),
                                border: Border.all(color: style.color.withAlpha(60)),
                              ),
                              child: Icon(Icons.add_rounded, color: style.color, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: count),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Text(
                            '$v',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 26,
                              height: 1,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          count == 1 ? 'item' : 'items',
                          style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.displayName,
                      style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      latestTitle == null ? 'Tap + to add one' : 'Latest · $latestTitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: latestTitle == null ? style.color : AppColors.textMutedNavy,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
