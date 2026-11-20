import 'package:flutter/material.dart';
import '../../../../core/brand/vault_mark.dart';
import '../../../../core/constants/app_colors.dart';

/// The MyVault logo (shield and keyhole, see [VaultMarkPainter]) on its brand tile, with a
/// soft halo. Matches the launcher icon.
class VaultShieldLogo extends StatelessWidget {
  final double size;

  const VaultShieldLogo({
    super.key,
    this.size = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryLight.withAlpha(100),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(30),
            blurRadius: 24,
            spreadRadius: 6,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.22),
            gradient: VaultMarkPainter.brandGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withAlpha(60),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CustomPaint(
            painter: VaultMarkPainter(markScale: 0.62, shadow: size >= 48),
          ),
        ),
      ),
    );
  }
}

