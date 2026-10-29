import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

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

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add to Vault',
                style: TextStyle(
                  color: AppColors.textPrimaryNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.categoryPasswordsBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.key_rounded, color: AppColors.categoryPasswords),
                ),
                title: const Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Website, application, or account login credentials'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add-item');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.categoryIdCardsBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.badge_outlined, color: AppColors.categoryIdCards),
                ),
                title: const Text('ID Card', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Aadhaar, PAN, Passport, Driving License, Voter ID'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add-id');
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.categoryDocumentsBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.file_present_rounded, color: AppColors.categoryDocuments),
                ),
                title: const Text('Document or Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Encrypted PDF, JPG, PNG, WEBP, or TXT file'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/add-document');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemSheet(context),
        backgroundColor: AppColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 8,
        surfaceTintColor: Colors.transparent,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home (index 0)
            _buildNavItem(
              index: 0,
              icon: Icons.home_rounded,
              label: 'Home',
              isSelected: currentIndex == 0,
            ),
            // Search (index 1)
            _buildNavItem(
              index: 1,
              icon: Icons.search_rounded,
              label: 'Search',
              isSelected: currentIndex == 1,
            ),
            // Gap for center floating action button
            const SizedBox(width: 48),
            // Categories (index 2)
            _buildNavItem(
              index: 2,
              icon: Icons.grid_view_rounded,
              label: 'Categories',
              isSelected: currentIndex == 2,
            ),
            // Settings (index 3)
            _buildNavItem(
              index: 3,
              icon: Icons.settings_outlined,
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
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _onTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? AppColors.primary : AppColors.textMutedNavy,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textMutedNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

