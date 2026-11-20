import '../../core/brand/vault_mark.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import 'add_to_vault_sheet.dart';

class MainScaffoldShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffoldShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: VaultMarkPainter.brandGradient,
          boxShadow: [
            BoxShadow(
              color: VaultMarkPainter.gradientStart.withAlpha(100),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showAddToVaultSheet(context),
            customBorder: const CircleBorder(),
            child: const Center(
              child: Icon(Icons.add_rounded, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: AppColors.surface,
        // A light lift: a heavy shadow reads as a grey band above the bar.
        elevation: 4,
        shadowColor: Colors.black.withAlpha(AppColors.isDark ? 90 : 30),
        surfaceTintColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        height: 68,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home (index 0)
            _buildNavItem(
              index: 0,
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              isSelected: currentIndex == 0,
            ),
            // Search (index 1)
            _buildNavItem(
              index: 1,
              icon: Icons.search_rounded,
              activeIcon: Icons.search_rounded,
              label: 'Search',
              isSelected: currentIndex == 1,
            ),
            // Gap for center floating action button
            const SizedBox(width: 48),
            // Categories (index 2)
            _buildNavItem(
              index: 2,
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view_rounded,
              label: 'Categories',
              isSelected: currentIndex == 2,
            ),
            // Settings (index 3)
            _buildNavItem(
              index: 3,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: 'Settings',
              isSelected: currentIndex == 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onTap(index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textMutedNavy,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMutedNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

