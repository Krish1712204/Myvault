import 'package:myvault/features/vault/data/vault_repository.dart';
import 'package:myvault/features/vault_items/data/vault_item_model.dart';
import 'package:myvault/shared/state/item_search.dart';

/// The app's real search: every item, filtered in memory by [itemMatchesQuery]
/// (the same function global Search and the per-category search box use).
Future<List<VaultItem>> searchVault(VaultRepository repository, String query) async =>
    (await repository.getAllItems()).where((item) => itemMatchesQuery(item, query)).toList();

Future<List<VaultItem>> itemsInCategory(VaultRepository repository, VaultCategory category) async =>
    (await repository.getAllItems()).where((item) => item.category == category).toList();

Future<List<VaultItem>> favouriteItems(VaultRepository repository) async =>
    (await repository.getAllItems()).where((item) => item.isFavourite).toList();
