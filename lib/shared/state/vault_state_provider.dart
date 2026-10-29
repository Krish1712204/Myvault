import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/domain/vault_auth_notifier.dart';
import '../../features/auth/domain/vault_auth_state.dart';
import '../../features/vault/data/vault_models.dart';
import '../../features/vault/data/vault_repository.dart';
import '../../features/vault_items/data/mock_vault_data.dart';
import '../../features/vault_items/data/vault_item_model.dart';

/// Manages vault items state (supports real SQLCipher storage via repository)
class VaultItemsNotifier extends StateNotifier<List<VaultItem>> {
  final VaultRepository _repository;
  final Ref _ref;

  VaultItemsNotifier(this._repository, this._ref) : super([]) {
    _initListener();
  }

  void _initListener() {
    _ref.listen<VaultAuthState>(vaultAuthStateProvider, (previous, next) {
      if (next.status == VaultStatus.unlocked) {
        loadItems();
      } else if (next.status == VaultStatus.locked || next.status == VaultStatus.uninitialized) {
        state = [];
      }
    });

    if (_ref.read(vaultAuthStateProvider).status == VaultStatus.unlocked) {
      loadItems();
    }
  }

  /// Reloads all items from the encrypted database
  Future<void> loadItems() async {
    try {
      final items = await _repository.getAllItems();
      state = items;
    } catch (_) {
      if (state.isEmpty) {
        state = MockVaultData.items;
      }
    }
  }

  /// Saves (creates or updates) a password item with full relational mapping
  Future<void> savePasswordItem({
    String? id,
    required String title,
    String? websiteUrl,
    String? username,
    required String password,
    String subcategory = 'Website',
    String? notes,
    bool isFavourite = false,
  }) async {
    final isNew = id == null || id.isEmpty;
    final itemId = isNew ? 'pwd_${DateTime.now().millisecondsSinceEpoch}' : id;
    final now = DateTime.now().millisecondsSinceEpoch;

    final item = VaultItem(
      id: itemId,
      title: title,
      subtitle: (username != null && username.isNotEmpty) ? username : subcategory,
      category: VaultCategory.passwords,
      url: websiteUrl,
      username: username,
      password: password,
      details: notes,
      subcategory: subcategory,
      isFavourite: isFavourite,
      createdAt: now,
      updatedAt: now,
    );

    final pwdEntry = PasswordEntry(
      id: 'entry_$itemId',
      itemId: itemId,
      username: username,
      encryptedPassword: password,
      websiteUrl: websiteUrl,
      notes: notes,
    );

    if (isNew) {
      await _repository.insertItem(item, passwordEntry: pwdEntry);
    } else {
      await _repository.updateItem(item, passwordEntry: pwdEntry);
    }

    await loadItems();
  }

  /// Adds a generic vault item
  Future<void> addItem(VaultItem item) async {
    try {
      await _repository.insertItem(item);
      await loadItems();
    } catch (_) {
      state = [item, ...state];
    }
  }

  /// Toggles an item's favourite status
  Future<void> toggleFavourite(String id) async {
    try {
      await _repository.toggleFavourite(id);
      await loadItems();
    } catch (_) {
      state = state.map((item) {
        if (item.id == id) {
          return item.copyWith(isFavourite: !item.isFavourite);
        }
        return item;
      }).toList();
    }
  }

  /// Deletes an item from the encrypted database
  Future<void> removeItem(String id) async {
    try {
      await _repository.deleteItem(id);
      await loadItems();
    } catch (_) {
      state = state.where((item) => item.id != id).toList();
    }
  }
}

final vaultItemsProvider =
    StateNotifierProvider<VaultItemsNotifier, List<VaultItem>>((ref) {
  return VaultItemsNotifier(ref.watch(vaultRepositoryProvider), ref);
});

/// Returns items filtered by category
final itemsByCategoryProvider =
    Provider.family<List<VaultItem>, VaultCategory>((ref, category) {
  final items = ref.watch(vaultItemsProvider);
  return items.where((item) => item.category == category).toList();
});

/// Returns items marked as favourite
final favouriteItemsProvider = Provider<List<VaultItem>>((ref) {
  final items = ref.watch(vaultItemsProvider);
  return items.where((item) => item.isFavourite).toList();
});

/// Count for specific categories displayed on dashboard
final categoryCountsProvider = Provider<Map<VaultCategory, int>>((ref) {
  final items = ref.watch(vaultItemsProvider);
  final map = <VaultCategory, int>{
    for (final c in VaultCategory.values) c: 0,
  };
  for (final item in items) {
    map[item.category] = (map[item.category] ?? 0) + 1;
  }
  return map;
});

/// Recent searches list
class RecentSearchesNotifier extends StateNotifier<List<String>> {
  RecentSearchesNotifier()
      : super(['google', 'passport', 'bank', 'insurance', 'office id']);

  void addSearch(String query) {
    if (query.trim().isEmpty) return;
    state = [query.trim(), ...state.where((q) => q != query.trim())];
  }

  void clearAll() {
    state = [];
  }
}

final recentSearchesProvider =
    StateNotifierProvider<RecentSearchesNotifier, List<String>>((ref) {
  return RecentSearchesNotifier();
});
