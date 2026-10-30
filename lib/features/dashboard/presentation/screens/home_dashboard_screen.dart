import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/profile/user_profile_provider.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/notifications_sheet.dart';
import '../../../../shared/widgets/user_profile_sheet.dart';
import '../../../vault_items/data/vault_item_model.dart';
import '../widgets/category_grid_card.dart';
import '../widgets/hero_stats_card.dart';
import '../widgets/quick_actions_row.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(categoryCountsProvider);
    final favourites = ref.watch(favouriteItemsProvider);
    final userProfile = ref.watch(userProfileProvider);
    final totalItems = counts.values.fold<int>(0, (prev, curr) => prev + curr);

    final hasCustomPhoto = userProfile.photoPath != null && File(userProfile.photoPath!).existsSync();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'MyVault',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Notification bell with badge -> Opens functional Notifications Sheet
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimaryNavy, size: 24),
                tooltip: 'Notifications & Alerts',
                onPressed: () => NotificationsSheet.show(context),
              ),
              Positioned(
                right: 12,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          // User profile avatar (Krishna Shelar) -> Opens Profile Sheet
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 4.0),
            child: InkWell(
              onTap: () => UserProfileSheet.show(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                  border: Border.all(color: AppColors.primary.withAlpha(80), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: hasCustomPhoto
                      ? Image.file(
                          File(userProfile.photoPath!),
                          width: 38,
                          height: 38,
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: Text(
                            'KS',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          children: [
            // Blue Gradient Hero Stats Card
            HeroStatsCard(
              totalItems: totalItems,
              favouriteItems: favourites.length,
            ),
            const SizedBox(height: AppSpacing.lg),
            // 2x3 Categories Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.35,
              children: VaultCategory.values.map((cat) {
                return CategoryGridCard(
                  category: cat,
                  count: counts[cat] ?? 0,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Quick Actions Section
            const QuickActionsRow(),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

