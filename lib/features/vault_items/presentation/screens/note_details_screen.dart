import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/security/clipboard_service.dart';
import '../../../../shared/state/vault_state_provider.dart';
import '../../../../shared/widgets/bold_text.dart';
import '../../../../shared/widgets/detail_actions.dart';
import '../../data/vault_item_model.dart';

class NoteDetailsScreen extends ConsumerStatefulWidget {
  final String itemId;

  const NoteDetailsScreen({
    super.key,
    required this.itemId,
  });

  @override
  ConsumerState<NoteDetailsScreen> createState() => _NoteDetailsScreenState();
}

class _NoteDetailsScreenState extends ConsumerState<NoteDetailsScreen> {
  Future<void> _confirmDelete(BuildContext context, VaultItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Note?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryNavy),
        ),
        content: Text(
          'Are you sure you want to permanently delete "${item.title}" from your vault? This action cannot be undone.',
          style: TextStyle(color: AppColors.textPrimaryNavy),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMutedNavy)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
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
        SnackBar(
          content: Text('${item.title} deleted from vault'),
          backgroundColor: AppColors.textPrimaryNavy,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(vaultItemsProvider);
    final matches = allItems.where((i) => i.id == widget.itemId).toList();

    if (matches.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text('Note Details'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 48, color: AppColors.textMutedNavy),
              const SizedBox(height: 12),
              Text('Note not found', style: TextStyle(color: AppColors.textMutedNavy)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final item = matches.first;
    final rawContent = item.details ?? '';
    final content = rawContent;
    final plainContent = stripBoldMarkers(rawContent);

    final wordCount = plainContent.trim().isEmpty ? 0 : plainContent.trim().split(RegExp(r'\s+')).length;
    final charCount = plainContent.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Note Details',
          style: TextStyle(
            color: AppColors.textPrimaryNavy,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              item.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
              color: item.isFavourite ? Colors.amber : AppColors.textMutedNavy,
              size: 24,
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
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.categoryNotesBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.sticky_note_2_rounded,
                            color: AppColors.categoryNotes,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: AppColors.textPrimaryNavy,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      item.subcategory ?? 'General',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$wordCount words · $charCount chars',
                                    style: TextStyle(
                                      color: AppColors.textMutedNavy,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // Note Content Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Content',
                          style: TextStyle(
                            color: AppColors.textPrimaryNavy,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            if (content.isNotEmpty) {
                              // Secure notes hold recovery codes and the like: auto-clear.
                              ClipboardService.copySensitive(
                                context: context,
                                text: plainContent,
                                label: 'Note content',
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                          label: const Text(
                            'Copy',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    content.isEmpty
                        ? Text('(Empty note)', style: TextStyle(color: AppColors.textMutedNavy, fontSize: 15))
                        : SelectableText.rich(
                            TextSpan(
                              children: boldSpans(
                                content,
                                TextStyle(color: AppColors.textPrimaryNavy, fontSize: 15, height: 1.5),
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
              DetailActions(
                onDelete: () => _confirmDelete(context, item),
                onEdit: () => context.push('/edit-note/${item.id}'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
