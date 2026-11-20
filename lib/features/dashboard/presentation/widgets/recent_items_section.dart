import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/navigation/item_routes.dart';
import '../../../../shared/widgets/add_to_vault_sheet.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../../core/ui/formatters.dart';
import '../../../vault_items/data/vault_item_model.dart';

/// The five most recently changed items, or a friendly empty state.
class RecentItemsSection extends StatelessWidget {
  final List<VaultItem> items;

  const RecentItemsSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = AppColors.textPrimaryNavy;
    final surface = AppColors.surface;
    final border = AppColors.border;
    final recent = [...items]..sort((a, b) => (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0));
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recently Updated',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(isDark ? 50 : 22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 30),
                ),
                const SizedBox(height: 12),
                Text('Nothing here yet', style: TextStyle(color: textPrimary, fontSize: 15.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Add a password, ID or document. It is encrypted the moment you save it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => showAddToVaultSheet(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add your first item'),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                for (final (i, item) in recent.take(5).indexed) ...[
                  if (i > 0) Divider(height: 1, indent: 66, color: border),
                  _RecentRow(item: item, now: now, textPrimary: textPrimary),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  final VaultItem item;
  final DateTime now;
  final Color textPrimary;

  const _RecentRow({required this.item, required this.now, required this.textPrimary});

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(item.category);
    return PressableScale(
      pressedScale: 0.98,
      onTap: () => context.push(detailRouteFor(item)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(13)),
              child: Icon(style.icon, color: style.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textPrimary, fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.category.displayName} · ${relativeTime(item.updatedAt ?? 0, now)}',
                    style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (item.isFavourite) const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMutedNavy),
          ],
        ),
      ),
    );
  }
}
