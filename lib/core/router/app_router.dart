import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/vault_auth_notifier.dart';
import '../../features/auth/domain/vault_auth_state.dart';
import '../../features/auth/presentation/screens/create_vault_screen.dart';
import '../../features/auth/presentation/screens/unlock_vault_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/categories/presentation/screens/categories_screen.dart';
import '../../features/categories/presentation/screens/category_items_screen.dart';
import '../../features/dashboard/presentation/screens/home_dashboard_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/settings/presentation/screens/backup_restore_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/vault_items/presentation/screens/add_contact_screen.dart';
import '../../features/vault_items/presentation/screens/add_document_screen.dart';
import '../../features/vault_items/presentation/screens/add_identity_screen.dart';
import '../../features/vault_items/presentation/screens/add_item_screen.dart';
import '../../features/vault_items/presentation/screens/add_note_screen.dart';
import '../../features/vault_items/presentation/screens/contact_details_screen.dart';
import '../../features/vault_items/presentation/screens/document_details_screen.dart';
import '../../features/vault_items/presentation/screens/identity_details_screen.dart';
import '../../features/vault_items/presentation/screens/note_details_screen.dart';
import '../../features/vault_items/presentation/screens/password_details_screen.dart';
import '../../shared/widgets/main_scaffold_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Listenable that notifies GoRouter to re-evaluate redirect rules when auth state changes
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<VaultAuthState>(
      vaultAuthStateProvider,
      (_, __) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(vaultAuthStateProvider);
    final status = authState.status;
    final location = state.uri.path;

    final isAuthRoute = location == '/welcome' ||
        location == '/create-vault' ||
        location == '/unlock';

    // 1. Initial startup or vault not created -> keep on onboarding
    if (status == VaultStatus.initial || status == VaultStatus.uninitialized) {
      if (location != '/welcome' && location != '/create-vault') {
        return '/welcome';
      }
      return null;
    }

    // 2. Vault exists and is locked -> show welcome screen first, or unlock
    if (status == VaultStatus.locked) {
      if (location != '/unlock' && location != '/welcome') {
        return '/welcome';
      }
      return null;
    }

    // 3. Vault is unlocked -> if user visits auth routes, redirect to dashboard
    if (status == VaultStatus.unlocked) {
      if (isAuthRoute) {
        return '/';
      }
      return null;
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/welcome',
    refreshListenable: notifier,
    redirect: notifier.redirect,
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
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/create-vault',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const CreateVaultScreen(),
      ),
      GoRoute(
        path: '/unlock',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const UnlockVaultScreen(),
      ),

      // Standalone Feature Detail Routes
      GoRoute(
        path: '/category/:type',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final type = state.pathParameters['type'] ?? 'passwords';
          return CategoryItemsScreen(categoryKey: type);
        },
      ),
      GoRoute(
        path: '/add-item',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddItemScreen(),
      ),
      GoRoute(
        path: '/edit-password/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return AddItemScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/password-details/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'pwd_1';
          return PasswordDetailsScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/id-details/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return IdentityDetailsScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/add-id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddIdentityScreen(),
      ),
      GoRoute(
        path: '/edit-id/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return AddIdentityScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/document-details/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return DocumentDetailsScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/add-document',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddDocumentScreen(),
      ),
      GoRoute(
        path: '/edit-document/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return AddDocumentScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/note-details/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return NoteDetailsScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/add-note',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddNoteScreen(),
      ),
      GoRoute(
        path: '/edit-note/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return AddNoteScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/contact-details/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ContactDetailsScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/add-contact',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddContactScreen(),
      ),
      GoRoute(
        path: '/edit-contact/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'];
          return AddContactScreen(itemId: id);
        },
      ),
      GoRoute(
        path: '/backup-restore',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const BackupRestoreScreen(),
      ),
    ],
  );
});
