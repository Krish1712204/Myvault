import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../shared/navigation/item_routes.dart';
import '../../../../shared/state/item_search.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../vault_items/data/vault_item_model.dart';
import '../widgets/file_grid.dart';
import '../../../auth/domain/vault_auth_notifier.dart';

import '../../../../shared/widgets/letter_avatar.dart';
import '../../../../core/ui/formatters.dart';
import '../../../../core/ui/user_message.dart';
import '../../../../shared/state/item_display.dart';
import '../../../../core/security/clipboard_service.dart';

class CategoryItemsScreen extends ConsumerStatefulWidget {
  final String categoryKey;

  const CategoryItemsScreen({
    super.key,
    required this.categoryKey,
  });

  @override
  ConsumerState<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends ConsumerState<CategoryItemsScreen> {
  final _searchController = TextEditingController();
  String _selectedSubcategory = 'All';
  bool _isSelectionMode = false;
  bool _photoGrid = true;
  final Set<String> _selectedItemIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmBulkDelete(BuildContext context) async {
    final count = _selectedItemIds.length;
    if (count == 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $count Items?'),
        content: Text('Are you sure you want to permanently delete $count selected items? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final idsToDelete = List<String>.from(_selectedItemIds);
      setState(() {
        _isSelectionMode = false;
        _selectedItemIds.clear();
      });
      final deleted = await ref.read(vaultItemsProvider.notifier).removeItems(idsToDelete);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        deleted
            ? SnackBar(content: Text('Deleted $count items'))
            : const SnackBar(
                content: Text('Some items could not be deleted. Please try again.'),
                backgroundColor: AppColors.error,
              ),
      );
    }
  }

  Future<void> _uploadVcfFile(BuildContext context) async {
    try {
      ref.read(vaultAuthStateProvider.notifier).allowExternalActivity();
      final files = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        // The picker leaves an unencrypted copy in the app cache; remove it now.
        FilePicker.clearTemporaryFiles().ignore();
        final content = utf8.decode(bytes, allowMalformed: true);
        final result = await ref.read(vaultItemsProvider.notifier).importContactsFromVcf(content);
        if (context.mounted) {
          final imported = '${result.imported} contact${result.imported == 1 ? '' : 's'} imported';
          final skipped = result.duplicates > 0
              ? ' (${result.duplicates} already in your vault, skipped)'
              : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$imported$skipped'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not import contacts. ${userMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to permanently delete "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final deleted = await ref.read(vaultItemsProvider.notifier).removeItem(item.id);
      if (!context.mounted) return;
      if (!deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete item. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.categoryKey.toLowerCase();
    final isFavouritesCategory = key == 'favourites' || key == 'favorites';
    final category = isFavouritesCategory
        ? VaultCategory.passwords
        : VaultCategory.fromKey(widget.categoryKey);

    final List<VaultItem> items = isFavouritesCategory
        ? ref.watch(favouriteItemsProvider)
        : ref.watch(itemsByCategoryProvider(category));
    final query = _searchController.text.trim().toLowerCase();

    final subcategories = _filtersFor(isFavouritesCategory ? null : category, items);
    // A filter that no longer applies (e.g. its last item was deleted) falls back to All.
    final activeFilter = subcategories.contains(_selectedSubcategory) ? _selectedSubcategory : 'All';

    final filteredItems = items.where((item) {
      if (activeFilter != 'All' && _filterLabelOf(isFavouritesCategory ? null : category, item) != activeFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      return itemMatchesQuery(item, query);
    }).toList();

    if (category == VaultCategory.contacts) {
      filteredItems.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedItemIds.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _isSelectionMode
            ? AppBar(
                backgroundColor: AppColors.surface,
                leading: IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textPrimaryNavy),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedItemIds.clear();
                    });
                  },
                ),
                title: Text(
                  '${_selectedItemIds.length} selected',
                  style: TextStyle(
                    color: AppColors.textPrimaryNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      _selectedItemIds.length == filteredItems.length && filteredItems.isNotEmpty
                          ? Icons.deselect_rounded
                          : Icons.select_all_rounded,
                      color: AppColors.primary,
                    ),
                    tooltip: _selectedItemIds.length == filteredItems.length && filteredItems.isNotEmpty
                        ? 'Deselect All'
                        : 'Select All',
                    onPressed: () {
                      setState(() {
                        if (_selectedItemIds.length == filteredItems.length) {
                          _selectedItemIds.clear();
                        } else {
                          _selectedItemIds.addAll(filteredItems.map((e) => e.id));
                        }
                      });
                    },
                  ),
                  if (_selectedItemIds.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                      tooltip: 'Delete Selected',
                      onPressed: () => _confirmBulkDelete(context),
                    ),
                  const SizedBox(width: 8),
                ],
              )
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => context.pop(),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isFavouritesCategory ? 'Favourites' : category.displayName,
                      style: TextStyle(
                        color: AppColors.textPrimaryNavy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${filteredItems.length} items',
                      style: TextStyle(
                        color: AppColors.textMutedNavy,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (_supportsGrid(isFavouritesCategory, category))
                    IconButton(
                      tooltip: _photoGrid ? 'Show as list' : 'Show as grid',
                      icon: Icon(
                        _photoGrid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                        color: AppColors.primary,
                      ),
                      onPressed: () => setState(() => _photoGrid = !_photoGrid),
                    ),
                  if (filteredItems.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.checklist_rounded, color: AppColors.primary, size: 24),
                      tooltip: 'Select items',
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      },
                    ),
                  if (!isFavouritesCategory && category == VaultCategory.contacts)
                    IconButton(
                      icon: const Icon(Icons.file_upload_outlined, color: AppColors.primary, size: 24),
                      tooltip: 'Upload .vcf File',
                      onPressed: () => _uploadVcfFile(context),
                    ),
                  if (!isFavouritesCategory)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 26),
                      tooltip: 'Add',
                      onPressed: () => context.push(addRouteFor(category)),
                    ),
                  const SizedBox(width: 8),
                ],
              ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search ${isFavouritesCategory ? 'favourites' : category.displayName.toLowerCase()}...',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMutedNavy),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, color: AppColors.textMutedNavy),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                  ),
                  if (subcategories.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: subcategories.map((sub) {
                          final isSelected = activeFilter == sub;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(sub),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedSubcategory = sub),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surface,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        'No ${category.displayName.toLowerCase()} found',
                        style: TextStyle(color: AppColors.textMutedNavy),
                      ),
                    )
                  : (_supportsGrid(isFavouritesCategory, category) && _photoGrid)
                      ? FileGrid(
                          items: filteredItems,
                          showTitles: category == VaultCategory.documents,
                          selectionMode: _isSelectionMode,
                          selectedIds: _selectedItemIds,
                          onTap: (item) {
                            if (_isSelectionMode) {
                              setState(() {
                                if (!_selectedItemIds.remove(item.id)) _selectedItemIds.add(item.id);
                                if (_selectedItemIds.isEmpty) _isSelectionMode = false;
                              });
                            } else {
                              context.push(detailRouteFor(item));
                            }
                          },
                          onLongPress: (item) => setState(() {
                            _isSelectionMode = true;
                            _selectedItemIds.add(item.id);
                          }),
                          onSelectGroup: (ids, select) => setState(() {
                            _isSelectionMode = true;
                            select ? _selectedItemIds.addAll(ids) : _selectedItemIds.removeAll(ids);
                            if (_selectedItemIds.isEmpty) _isSelectionMode = false;
                          }),
                        )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final isSelected = _selectedItemIds.contains(item.id);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected ? AppColors.primaryLight : AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            onLongPress: () {
                              if (!_isSelectionMode) {
                                setState(() {
                                  _isSelectionMode = true;
                                  _selectedItemIds.add(item.id);
                                });
                              }
                            },
                            onTap: () {
                              if (_isSelectionMode) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedItemIds.remove(item.id);
                                    if (_selectedItemIds.isEmpty) {
                                      _isSelectionMode = false;
                                    }
                                  } else {
                                    _selectedItemIds.add(item.id);
                                  }
                                });
                                return;
                              }
                              if (category == VaultCategory.passwords) {
                                context.push('/password-details/${item.id}');
                              } else if (category == VaultCategory.idCards) {
                                context.push('/id-details/${item.id}');
                              } else if (category == VaultCategory.documents || category == VaultCategory.photos) {
                                context.push('/document-details/${item.id}');
                              } else if (category == VaultCategory.notes) {
                                context.push('/note-details/${item.id}');
                              } else if (category == VaultCategory.contacts) {
                                context.push('/contact-details/${item.id}');
                              } else {
                                _showItemDetailsDialog(context, item);
                              }
                            },
                            leading: _isSelectionMode
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: isSelected,
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        onChanged: (_) {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedItemIds.remove(item.id);
                                              if (_selectedItemIds.isEmpty) {
                                                _isSelectionMode = false;
                                              }
                                            } else {
                                              _selectedItemIds.add(item.id);
                                            }
                                          });
                                        },
                                      ),
                                      _buildItemAvatar(item),
                                    ],
                                  )
                                : _buildItemAvatar(item),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                color: AppColors.textPrimaryNavy,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            subtitle: category == VaultCategory.notes
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.textMutedNavy,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Updated ${relativeTime(item.updatedAt ?? item.createdAt ?? 0, DateTime.now())}',
                                        style: TextStyle(
                                          color: AppColors.textMutedNavy,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    item.displaySubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: AppColors.textMutedNavy,
                                      fontSize: 13,
                                    ),
                                  ),
                            trailing: _isSelectionMode
                                ? null
                                : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (category == VaultCategory.documents || category == VaultCategory.photos)
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 22),
                                    tooltip: 'Preview',
                                    onPressed: () => context.push('/document-details/${item.id}'),
                                  ),
                                IconButton(
                                  icon: Icon(
                                    item.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: item.isFavourite ? Colors.amber : AppColors.textMutedNavy,
                                    size: 22,
                                  ),
                                  onPressed: () async {
                                    final saved = await ref.read(vaultItemsProvider.notifier).toggleFavourite(item.id);
                                    if (!saved && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Could not update favourite. Please try again.'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert_rounded, color: AppColors.textMutedNavy, size: 20),
                                  onSelected: (action) {
                                    if (action == 'view') {
                                      if (category == VaultCategory.passwords) {
                                        context.push('/password-details/${item.id}');
                                      } else if (category == VaultCategory.idCards) {
                                        context.push('/id-details/${item.id}');
                                      } else if (category == VaultCategory.documents || category == VaultCategory.photos) {
                                        context.push('/document-details/${item.id}');
                                      } else if (category == VaultCategory.notes) {
                                        context.push('/note-details/${item.id}');
                                      } else if (category == VaultCategory.contacts) {
                                        context.push('/contact-details/${item.id}');
                                      } else {
                                        _showItemDetailsDialog(context, item);
                                      }
                                    } else if (action == 'edit') {
                                      if (category == VaultCategory.passwords) {
                                        context.push('/edit-password/${item.id}');
                                      } else if (category == VaultCategory.idCards) {
                                        context.push('/edit-id/${item.id}');
                                      } else if (category == VaultCategory.documents || category == VaultCategory.photos) {
                                        context.push('/edit-document/${item.id}');
                                      } else if (category == VaultCategory.notes) {
                                        context.push('/edit-note/${item.id}');
                                      } else if (category == VaultCategory.contacts) {
                                        context.push('/edit-contact/${item.id}');
                                      } else {
                                        context.push('/add-item');
                                      }
                                    } else if (action == 'delete') {
                                      _confirmDelete(context, item);
                                    } else if (action == 'copy') {
                                      if (category == VaultCategory.passwords && item.password != null) {
                                        ClipboardService.copySensitive(
                                          context: context,
                                          text: item.password!,
                                          label: 'Password',
                                        );
                                      } else if (category == VaultCategory.idCards && item.documentNumber != null && item.documentNumber!.isNotEmpty) {
                                        ClipboardService.copySensitive(
                                          context: context,
                                          text: item.documentNumber!,
                                          label: '${item.title} Number',
                                        );
                                      } else if (category == VaultCategory.notes && item.details != null && item.details!.isNotEmpty) {
                                        ClipboardService.copyPublic(
                                          context: context,
                                          text: item.details!,
                                          label: 'Note Content',
                                        );
                                      } else if (category == VaultCategory.contacts && item.phoneNumber != null && item.phoneNumber!.isNotEmpty) {
                                        ClipboardService.copyPublic(
                                          context: context,
                                          text: item.phoneNumber!,
                                          label: 'Phone Number',
                                        );
                                      } else {
                                        ClipboardService.copyPublic(
                                          context: context,
                                          text: item.username ?? item.subtitle,
                                          label: 'Item Info',
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(value: 'view', child: Text('View Details')),
                                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(
                                      value: 'copy',
                                      child: Text(
                                        category == VaultCategory.passwords
                                            ? 'Copy Password'
                                            : (category == VaultCategory.idCards
                                                ? 'Copy ID Number'
                                                : (category == VaultCategory.notes
                                                    ? 'Copy Content'
                                                    : (category == VaultCategory.contacts
                                                        ? 'Copy Phone'
                                                        : 'Copy Info'))),
                                      ),
                                    ),
                                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildItemAvatar(VaultItem item) {
    if (item.category == VaultCategory.passwords) {
      return LetterAvatar(name: item.title, size: 42);
    }

    if (item.category == VaultCategory.contacts) {
      final name = item.title.trim();
      final parts = name.split(RegExp(r'\s+'));
      final initials = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : (name.isNotEmpty ? name[0].toUpperCase() : 'C');

      if (item.attachmentPath != null && item.attachmentPath!.isNotEmpty) {
        return FutureBuilder<Uint8List>(
          future: ref.read(vaultItemsProvider.notifier).getDecryptedFileBytes(item.attachmentPath!),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  snapshot.data!,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              );
            }
            return _buildInitialsContactAvatar(initials);
          },
        );
      }
      return _buildInitialsContactAvatar(initials);
    }

    IconData icon = Icons.lock_outline_rounded;
    Color color = AppColors.primary;
    Color bg = AppColors.primaryLight;

    if (item.category == VaultCategory.idCards) {
      icon = Icons.badge_outlined;
      color = AppColors.categoryIdCards;
      bg = AppColors.categoryIdCardsBg;
    } else if (item.category == VaultCategory.documents) {
      icon = Icons.picture_as_pdf_rounded;
      color = AppColors.categoryDocuments;
      bg = AppColors.categoryDocumentsBg;
    } else if (item.category == VaultCategory.photos) {
      icon = Icons.image_rounded;
      color = AppColors.categoryPhotos;
      bg = AppColors.categoryPhotosBg;
    } else if (item.category == VaultCategory.notes) {
      icon = Icons.sticky_note_2_rounded;
      color = AppColors.categoryNotes;
      bg = AppColors.categoryNotesBg;
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildInitialsContactAvatar(String initials) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.categoryContactsBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.categoryContacts,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  /// Photos and Documents can be shown as a preview grid.
  static bool _supportsGrid(bool isFavourites, VaultCategory category) =>
      !isFavourites && (category == VaultCategory.photos || category == VaultCategory.documents);

  /// The filter bucket an item belongs to. [category] is null for the Favourites list.
  static String _filterLabelOf(VaultCategory? category, VaultItem item) {
    if (category == null) return item.category.displayName;
    switch (category) {
      case VaultCategory.documents:
        final ext = (item.fileExtension ?? '').toLowerCase();
        final mime = (item.mimeType ?? '').toLowerCase();
        if (ext == '.pdf' || mime.contains('pdf')) return 'PDF';
        if (mime.startsWith('image/') || const ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic'].contains(ext)) {
          return 'Images';
        }
        return 'Other';
      case VaultCategory.idCards:
        final type = (item.documentType ?? '').trim();
        return type.isNotEmpty ? type : item.title;
      case VaultCategory.photos:
        return 'All';
      case VaultCategory.passwords:
      case VaultCategory.notes:
      case VaultCategory.contacts:
        final sub = (item.subcategory ?? '').trim();
        return sub.isEmpty ? 'Other' : sub;
    }
  }

  /// Filter chips built from the items actually present, so no chip ever leads to an empty
  /// list. Returns an empty list (no chips) when there is nothing to choose between.
  static List<String> _filtersFor(VaultCategory? category, List<VaultItem> items) {
    if (category == VaultCategory.photos) return const [];
    final labels = <String>{for (final item in items) _filterLabelOf(category, item)}.toList();
    if (category == null) {
      final order = VaultCategory.values.map((c) => c.displayName).toList();
      labels.sort((a, b) => order.indexOf(a).compareTo(order.indexOf(b)));
    } else {
      labels.sort((a, b) => a == 'Other' ? 1 : b == 'Other' ? -1 : a.toLowerCase().compareTo(b.toLowerCase()));
    }
    return labels.length < 2 ? const [] : ['All', ...labels];
  }

  void _showItemDetailsDialog(BuildContext context, VaultItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            _buildItemAvatar(item),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Subtitle: ${item.subtitle}', style: TextStyle(color: AppColors.textSecondaryNavy)),
            if (item.details != null) ...[
              const SizedBox(height: 8),
              Text('Details: ${item.details}', style: TextStyle(color: AppColors.textMutedNavy)),
            ],
            const SizedBox(height: 8),
            Text('Date: ${item.date}', style: TextStyle(color: AppColors.textMutedNavy, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

