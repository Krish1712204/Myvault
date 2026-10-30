import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../widgets/vault_shield_logo.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // In unit/widget tests, avoid infinite repeat so pumpAndSettle completes cleanly
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      _animController.forward();
    } else {
      _animController.repeat();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              // Top shield logo
              const VaultShieldLogo(size: 88),
              const SizedBox(height: AppSpacing.md),
              // Title
              Text(
                'MyVault',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 32,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your Personal Digital Vault',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimaryNavy,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'Secure. Private. Always with you.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMutedNavy,
                    ),
              ),
              const Spacer(),
              // Animated Central Illustration Graphic
              _buildAnimatedVaultGraphic(size.width),
              const Spacer(),
              // Carousel Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.border,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              // Get Started Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/create-vault');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedVaultGraphic(double screenWidth) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        // Continuous smooth sinusoidal motion
        final progress = _animController.value;
        final phase = progress * 2 * math.pi;

        // Individual physics calculations for dynamic 3D-like float
        final centerDocY = math.sin(phase) * 6.0;
        final auraScale = 1.0 + math.sin(phase) * 0.08;
        final auraAlpha = (80 + math.sin(phase) * 25).round().clamp(50, 115);

        final purpleNoteX = -math.sin(phase) * 4.0;
        final purpleNoteY = math.cos(phase) * 7.0;
        final purpleNoteAngle = 0.15 + math.cos(phase) * 0.035;

        final goldBadgeX = math.sin(phase) * 5.0;
        final goldBadgeY = -math.cos(phase) * 6.0;
        final goldBadgeAngle = -0.12 + math.sin(phase) * 0.04;

        final blueProfileX = math.cos(phase) * 4.0;
        final blueProfileY = -math.sin(phase) * 8.0;
        final blueProfileAngle = -0.10 + math.sin(phase) * 0.035;

        return SizedBox(
          height: 220,
          width: screenWidth * 0.85,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Background soft pulsing radial aura
              Transform.scale(
                scale: auraScale,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight.withAlpha(auraAlpha),
                  ),
                ),
              ),

              // 2. Floating Card: Purple Notes (Top-Right)
              Positioned(
                top: 25 + purpleNoteY,
                right: 40 + purpleNoteX,
                child: Transform.rotate(
                  angle: purpleNoteAngle,
                  child: Container(
                    width: 70,
                    height: 85,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E57C2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7E57C2).withAlpha(50),
                          blurRadius: 14,
                          offset: Offset(0, 4 + purpleNoteY.abs()),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.sticky_note_2_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),

              // 3. Floating Card: Gold / Yellow ID Badge (Bottom-Right)
              Positioned(
                bottom: 30 + goldBadgeY,
                right: 25 + goldBadgeX,
                child: Transform.rotate(
                  angle: goldBadgeAngle,
                  child: Container(
                    width: 65,
                    height: 75,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFA726),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFA726).withAlpha(50),
                          blurRadius: 14,
                          offset: Offset(0, 4 + goldBadgeY.abs()),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.badge_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),

              // 4. Main Center Document Stack (Gentle breathing float)
              Transform.translate(
                offset: Offset(0, centerDocY),
                child: Container(
                  width: 140,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textPrimaryNavy.withAlpha(18),
                        blurRadius: 20 + centerDocY.abs() * 2,
                        offset: Offset(0, 8 + centerDocY * 0.5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 50,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(100),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 70,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.check, color: AppColors.success, size: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Front Left Blue Profile Card (Dynamic gentle sway)
              Positioned(
                left: 30 + blueProfileX,
                bottom: 35 + blueProfileY,
                child: Transform.rotate(
                  angle: blueProfileAngle,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF29B6F6),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF29B6F6).withAlpha(60),
                          blurRadius: 14,
                          offset: Offset(0, 4 + blueProfileY.abs()),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
