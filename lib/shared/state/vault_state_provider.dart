import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/vault_items/data/mock_vault_data.dart';
import '../../features/vault_items/data/vault_item_model.dart';

/// Manages vault items state (supports adding, toggling favourites, deleting)
class VaultItemsNotifier extends StateNotifier<List<VaultItem>> {
  VaultItemsNotifier() : super(MockVaultData.items);

  void addItem(VaultItem item) {
    state = [item, ...state];
  }

  void toggleFavourite(String id) {
    state = state.map((item) {
      if (item.id == id) {
        return item.copyWith(isFavourite: !item.isFavourite);
      }
      return item;
    }).toList();
  }

  void removeItem(String id) {
    state = state.where((item) => item.id != id).toList();
  }
}

final vaultItemsProvider =
    StateNotifierProvider<VaultItemsNotifier, List<VaultItem>>((ref) {
  return VaultItemsNotifier();
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
    VaultCategory.passwords: 18,
    VaultCategory.idCards: 8,
    VaultCategory.documents: 10,
    VaultCategory.photos: 12,
    VaultCategory.notes: 6,
    VaultCategory.contacts: 2,
  };

  // Dynamically reflect any additional items added by the user
  for (final c in VaultCategory.values) {
    final count = items.where((i) => i.category == c).length;
    if (count > (map[c] ?? 0)) {
      map[c] = count;
    }
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

