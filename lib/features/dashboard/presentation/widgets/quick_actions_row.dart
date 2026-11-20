import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/add_to_vault_sheet.dart';
import '../../../../shared/widgets/pressable_scale.dart';
import '../../../vault_items/presentation/widgets/password_generator_sheet.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryNavy;

    final actions = [
      (Icons.add_rounded, 'Add Item', AppColors.gradientBlue, () => showAddToVaultSheet(context)),
      (Icons.password_rounded, 'Generate', AppColors.gradientGreen, () => PasswordGeneratorSheet.show(context)),
      (Icons.cloud_upload_rounded, 'Back Up', AppColors.gradientPurple, () => context.push('/backup-restore')),
      (Icons.upload_file_rounded, 'Import File', AppColors.gradientRose, () => context.push('/add-document')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (i, (icon, label, colors, onTap)) in actions.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: PressableScale(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                            boxShadow: [
                              BoxShadow(color: colors.last.withAlpha(70), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textPrimary, fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
