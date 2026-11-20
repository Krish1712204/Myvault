import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// The Delete / Edit row at the bottom of every item details screen, so all item types
/// look and behave the same: a quiet red Delete on the left, the primary Edit on the right.
class DetailActions extends StatelessWidget {
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final String editLabel;

  const DetailActions({
    super.key,
    required this.onDelete,
    required this.onEdit,
    this.editLabel = 'Edit',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withAlpha(150), width: 1.2),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('Delete'),
            onPressed: onDelete,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.edit_rounded, size: 19),
            label: Text(editLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
            onPressed: onEdit,
          ),
        ),
      ],
    );
  }
}
