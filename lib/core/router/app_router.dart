import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/create_vault_screen.dart';
import '../../features/auth/presentation/screens/unlock_vault_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/categories/presentation/screens/categories_screen.dart';
import '../../features/categories/presentation/screens/category_items_screen.dart';
import '../../features/dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/backup_restore_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/vault_items/presentation/screens/add_item_screen.dart';
import '../../features/vault_items/presentation/screens/password_details_screen.dart';
import '../../shared/widgets/main_scaffold_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Shell Route with Bottom Navigation Bar
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffoldShell(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: Home Dashboard
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeDashboardScreen(),
            ),
          ],
        ),
        // Tab 1: Search
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        // Tab 2: Categories
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/categories',
              builder: (context, state) => const CategoriesScreen(),
            ),
          ],
        ),
        // Tab 3: Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),

    // Standalone Onboarding & Auth Routes
    GoRoute(
      path: '/welcome',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/create-vault',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CreateVaultScreen(),
    ),
    GoRoute(
      path: '/unlock',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const UnlockVaultScreen(),
    ),

    // Standalone Feature Detail Routes
    GoRoute(
      path: '/category/:type',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final type = state.pathParameters['type'] ?? 'passwords';
        return CategoryItemsScreen(categoryKey: type);
      },
    ),
    GoRoute(
      path: '/add-item',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AddItemScreen(),
    ),
    GoRoute(
      path: '/password-details/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'pwd_1';
        return PasswordDetailsScreen(itemId: id);
      },
    ),
    GoRoute(
      path: '/backup-restore',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BackupRestoreScreen(),
    ),
  ],
);

