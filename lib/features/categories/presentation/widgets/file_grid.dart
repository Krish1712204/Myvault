import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../vault_items/data/vault_item_model.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Today", "Yesterday", "Wed, 28 Oct" (year added when it is not the current year).
String photoDayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  final base = '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
  return d.year == now.year ? base : '$base ${d.year}';
}

String _size(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  return '${(bytes / 1024).toStringAsFixed(bytes < 100 * 1024 ? 2 : 0)} kB';
}

/// Colour and icon for a file type that has no rendered preview.
(Color, IconData) _typeStyle(String ext) {
  switch (ext) {
    case 'pdf':
      return (AppColors.categoryDocuments, Icons.picture_as_pdf_rounded);
    case 'doc':
    case 'docx':
    case 'odt':
    case 'rtf':
      return (const Color(0xFF2563EB), Icons.description_rounded);
    case 'xls':
    case 'xlsx':
    case 'csv':
    case 'ods':
      return (const Color(0xFF16A34A), Icons.table_chart_rounded);
    case 'ppt':
    case 'pptx':
    case 'odp':
      return (const Color(0xFFEA580C), Icons.slideshow_rounded);
    case 'txt':
    case 'md':
    case 'json':
    case 'log':
      return (const Color(0xFF64748B), Icons.article_rounded);
    case 'zip':
    case 'rar':
    case '7z':
      return (const Color(0xFF7C3AED), Icons.folder_zip_rounded);
    default:
      return (const Color(0xFF0EA5E9), Icons.insert_drive_file_rounded);
  }
}

/// Gallery-style grid for photos and documents: files grouped by the day they were added,
/// three per row, each tile showing a preview (image or first PDF page) and its size.
/// Long-press starts selection; each day has a select-all circle.
class FileGrid extends StatelessWidget {
  final List<VaultItem> items;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<VaultItem> onTap;
  final ValueChanged<VaultItem> onLongPress;
  final void Function(List<String> ids, bool select) onSelectGroup;

  /// Show each file's name under the preview (documents are recognised by name).
  final bool showTitles;

  const FileGrid({
    super.key,
    required this.items,
    required this.selectionMode,
    required this.selectedIds,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectGroup,
    this.showTitles = false,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sorted = [...items]..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    final groups = <String, List<VaultItem>>{};
    for (final item in sorted) {
      final day = DateTime.fromMillisecondsSinceEpoch(item.createdAt ?? 0);
      groups.putIfAbsent(photoDayLabel(day, now), () => []).add(item);
    }

    return CustomScrollView(
      slivers: [
        for (final entry in groups.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Builder(builder: (context) {
                    final ids = entry.value.map((i) => i.id).toList();
                    final allSelected = selectionMode && ids.every(selectedIds.contains);
                    return IconButton(
                      tooltip: allSelected ? 'Deselect this day' : 'Select this day',
                      onPressed: () => onSelectGroup(ids, !allSelected),
                      icon: Icon(
                        allSelected ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                        color: allSelected ? AppColors.primary : AppColors.textMutedNavy,
                        size: 26,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: showTitles ? 0.78 : 1,
              ),
              itemCount: entry.value.length,
              itemBuilder: (context, i) {
                final item = entry.value[i];
                return _FileTile(
                  key: ValueKey(item.id),
                  item: item,
                  showTitle: showTitles,
                  selectionMode: selectionMode,
                  selected: selectedIds.contains(item.id),
                  onTap: () => onTap(item),
                  onLongPress: () => onLongPress(item),
                );
              },
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _FileTile extends ConsumerStatefulWidget {
  final VaultItem item;
  final bool showTitle;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _FileTile({
    super.key,
    required this.item,
    required this.showTitle,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  ConsumerState<_FileTile> createState() => _FileTileState();
}

class _FileTileState extends ConsumerState<_FileTile> {
  late final Future<Uint8List?> _thumb = ref.read(vaultItemsProvider.notifier).getThumbnail(widget.item);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final size = _size(item.fileSize);
    final ext = (item.fileExtension ?? '').replaceAll('.', '').toLowerCase();
    final (typeColor, typeIcon) = _typeStyle(ext);

    Widget placeholder(bool done) => Container(
          key: const ValueKey('placeholder'),
          color: typeColor.withAlpha(AppColors.isDark ? 45 : 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                done || item.category == VaultCategory.documents ? typeIcon : Icons.photo_rounded,
                color: typeColor.withAlpha(done ? 230 : 130),
                size: 34,
              ),
              // The PDF icon already says "PDF"; other types get a small extension badge.
              if (ext.isNotEmpty && ext != 'pdf' && item.category == VaultCategory.documents) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    ext.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        );

    final preview = ClipRRect(
      borderRadius: BorderRadius.circular(widget.selected ? 18 : 12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List?>(
            future: _thumb,
            builder: (context, snap) {
              final bytes = snap.data;
              final switcher = AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                // Fill the tile (the default layout would let previews shrink to their content).
                layoutBuilder: (current, previous) =>
                    Stack(fit: StackFit.expand, children: [...previous, if (current != null) current]),
                child: bytes != null
                    ? Image.memory(
                        bytes,
                        key: const ValueKey('img'),
                        fit: BoxFit.cover,
                        // PDF pages read best from the top.
                        alignment: ext == 'pdf' ? Alignment.topCenter : Alignment.center,
                        gaplessPlayback: true,
                      )
                    : placeholder(snap.connectionState == ConnectionState.done),
              );
              if (bytes == null || ext != 'pdf') return switcher;
              // A rendered first page looks like any image, so label it as a PDF.
              return Stack(
                fit: StackFit.expand,
                children: [
                  switcher,
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.categoryDocuments, borderRadius: BorderRadius.circular(5)),
                      child: const Text('PDF',
                          style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              );
            },
          ),
          if (size.isNotEmpty)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withAlpha(120), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  size,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (item.isFavourite)
            const Positioned(
              right: 6,
              bottom: 6,
              child: Icon(Icons.star_rounded, color: Colors.amber, size: 18, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
            ),
          if (widget.selectionMode)
            Positioned(
              top: 6,
              left: 6,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.selected ? AppColors.primary : Colors.black26,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: widget.selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
              ),
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: widget.selected ? 0.9 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: widget.showTitle
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: preview),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimaryNavy, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              )
            : preview,
      ),
    );
  }
}
