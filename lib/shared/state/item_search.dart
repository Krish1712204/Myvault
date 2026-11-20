import '../../features/vault_items/data/vault_item_model.dart';

/// Case-insensitive match of [query] against every user-visible text field of an item.
/// Used by global Search and by the per-category search box so both behave the same.
bool itemMatchesQuery(VaultItem item, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  bool has(String? value) => value != null && value.toLowerCase().contains(q);
  return has(item.title) ||
      has(item.subtitle) ||
      has(item.subcategory) ||
      has(item.category.displayName) ||
      has(item.url) ||
      has(item.username) ||
      has(item.details?.replaceAll('**', '')) ||
      has(item.tags) ||
      has(item.phoneNumber) ||
      has(item.secondaryPhone) ||
      has(item.email) ||
      has(item.secondaryEmail) ||
      has(item.company) ||
      has(item.jobTitle) ||
      has(item.address) ||
      has(item.documentType) ||
      has(item.documentNumber) ||
      has(item.fullName) ||
      has(item.fileName);
}
