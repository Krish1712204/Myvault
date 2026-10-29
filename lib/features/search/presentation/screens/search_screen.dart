import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../vault_items/data/vault_item_model.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  VaultCategory? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final allItems = ref.watch(vaultItemsProvider);
    final recentSearches = ref.watch(recentSearchesProvider);

    final filteredItems = allItems.where((item) {
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query) ||
          (item.username != null && item.username!.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find anything in your vault',
                    style: TextStyle(
                      color: AppColors.textMutedNavy,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Search Input Field
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search passwords, documents, notes...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMutedNavy),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, color: AppColors.textMutedNavy),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Category Filter Chips
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip('All', _selectedCategory == null, () {
                          setState(() => _selectedCategory = null);
                        }),
                        ...VaultCategory.values.map((cat) {
                          return _buildFilterChip(
                            cat.displayName,
                            _selectedCategory == cat,
                            () => setState(() => _selectedCategory = cat),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Content
            Expanded(
              child: query.isNotEmpty
                  ? _buildSearchResults(filteredItems)
                  : _buildDefaultSearchContent(recentSearches),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimaryNavy,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      ),
    );
  }

  Widget _buildDefaultSearchContent(List<String> recentSearches) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        if (recentSearches.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  color: AppColors.textPrimaryNavy,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              TextButton(
                onPressed: () => ref.read(recentSearchesProvider.notifier).clearAll(),
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          ...recentSearches.map((item) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded, color: AppColors.textMutedNavy, size: 20),
              title: Text(
                item,
                style: const TextStyle(
                  color: AppColors.textPrimaryNavy,
                  fontSize: 14,
                ),
              ),
              trailing: const Icon(Icons.north_west_rounded, color: AppColors.textMutedNavy, size: 16),
              onTap: () {
                _searchController.text = item;
                setState(() {});
              },
            );
          }),
          const SizedBox(height: AppSpacing.md),
        ],
        // Suggestions
        const Text(
          'Suggestions',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildSuggestionCard(
          icon: Icons.key_rounded,
          iconColor: AppColors.categoryPasswords,
          iconBg: AppColors.categoryPasswordsBg,
          title: 'Search Passwords',
          subtitle: 'Find accounts and logins',
          category: VaultCategory.passwords,
        ),
        _buildSuggestionCard(
          icon: Icons.badge_outlined,
          iconColor: AppColors.categoryIdCards,
          iconBg: AppColors.categoryIdCardsBg,
          title: 'Search ID Cards',
          subtitle: 'Find identity documents',
          category: VaultCategory.idCards,
        ),
        _buildSuggestionCard(
          icon: Icons.description_outlined,
          iconColor: AppColors.categoryDocuments,
          iconBg: AppColors.categoryDocumentsBg,
          title: 'Search Documents',
          subtitle: 'Find PDFs and files',
          category: VaultCategory.documents,
        ),
        _buildSuggestionCard(
          icon: Icons.image_outlined,
          iconColor: AppColors.categoryPhotos,
          iconBg: AppColors.categoryPhotosBg,
          title: 'Search Photos',
          subtitle: 'Find images and screenshots',
          category: VaultCategory.photos,
        ),
        _buildSuggestionCard(
          icon: Icons.sticky_note_2_outlined,
          iconColor: AppColors.categoryNotes,
          iconBg: AppColors.categoryNotesBg,
          title: 'Search Notes',
          subtitle: 'Find your notes',
          category: VaultCategory.notes,
        ),
        _buildSuggestionCard(
          icon: Icons.person_outline_rounded,
          iconColor: AppColors.categoryContacts,
          iconBg: AppColors.categoryContactsBg,
          title: 'Search Contacts',
          subtitle: 'Find people and details',
          category: VaultCategory.contacts,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildSuggestionCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VaultCategory category,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push('/category/${category.keyName}'),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textMutedNavy,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMutedNavy),
      ),
    );
  }

  Widget _buildSearchResults(List<VaultItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMutedNavy.withAlpha(120)),
            const SizedBox(height: 12),
            const Text(
              'No items found',
              style: TextStyle(
                color: AppColors.textPrimaryNavy,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try searching with a different keyword',
              style: TextStyle(color: AppColors.textMutedNavy, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () {
              if (item.category == VaultCategory.passwords) {
                context.push('/password-details/${item.id}');
              } else {
                context.push('/category/${item.category.keyName}');
              }
            },
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
            ),
            title: Text(
              item.title,
              style: const TextStyle(
                color: AppColors.textPrimaryNavy,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            subtitle: Text(
              item.subtitle,
              style: const TextStyle(
                color: AppColors.textMutedNavy,
                fontSize: 13,
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                item.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                color: item.isFavourite ? Colors.amber : AppColors.textMutedNavy,
              ),
              onPressed: () {
                ref.read(vaultItemsProvider.notifier).toggleFavourite(item.id);
              },
            ),
          ),
        );
      },
    );
  }
}

