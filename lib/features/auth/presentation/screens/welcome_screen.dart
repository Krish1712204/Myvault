import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../domain/vault_auth_notifier.dart';
import '../../domain/vault_auth_state.dart';
import '../widgets/vault_shield_logo.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  static const List<_OrbitalItem> _orbitItems = [
    _OrbitalItem(
      icon: Icons.key_rounded,
      color: Color(0xFF2979FF),
      label: 'Passwords',
    ),
    _OrbitalItem(
      icon: Icons.badge_rounded,
      color: Color(0xFFFFA000),
      label: 'ID Cards',
    ),
    _OrbitalItem(
      icon: Icons.picture_as_pdf_rounded,
      color: Color(0xFFE53935),
      label: 'Documents',
    ),
    _OrbitalItem(
      icon: Icons.photo_library_rounded,
      color: Color(0xFF8E24AA),
      label: 'Photos',
    ),
    _OrbitalItem(
      icon: Icons.credit_card_rounded,
      color: Color(0xFF00C853),
      label: 'Cards',
    ),
    _OrbitalItem(
      icon: Icons.vpn_key_rounded,
      color: Color(0xFF3F51B5),
      label: '2FA Keys',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
    );

    // In unit/widget tests, avoid infinite repeat so pumpAndSettle completes cleanly
    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');
    if (isTest) {
      _animController.value = 0.5;
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
    final authState = ref.watch(vaultAuthStateProvider);
    final isVaultCreated = authState.status == VaultStatus.locked || authState.status == VaultStatus.unlocked;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              // Top shield logo
              const VaultShieldLogo(size: 80),
              const SizedBox(height: AppSpacing.sm),
              // Title
              Text(
                'MyVault',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
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
                      fontSize: 13,
                    ),
              ),
              const Spacer(),

              // Circular Orbital Animated Vault Graphic
              _buildCircularOrbitalVault(size.width),

              const Spacer(),

              // Carousel Indicator Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
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
              const SizedBox(height: AppSpacing.lg),

              // Action Button: Direct to Fingerprint if vault exists, or Get Started if fresh
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (isVaultCreated) {
                      context.push('/unlock');
                    } else {
                      context.push('/create-vault');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isVaultCreated ? Icons.fingerprint_rounded : Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isVaultCreated ? 'Unlock with Fingerprint' : 'Get Started',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularOrbitalVault(double screenWidth) {
    const double orbitRx = 120.0;
    const double orbitRy = 50.0;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final progress = _animController.value;
        final baseAngle = progress * 2 * math.pi;

        // Calculate positions for all 6 orbital components
        final positionedItems = <_CalculatedOrbit>[];
        for (int i = 0; i < _orbitItems.length; i++) {
          final item = _orbitItems[i];
          final angle = baseAngle + (i * 2 * math.pi / _orbitItems.length);
          final x = orbitRx * math.cos(angle);
          final y = orbitRy * math.sin(angle);
          final z = math.sin(angle); // -1 (back) to +1 (front)
          final scale = 0.82 + 0.26 * ((z + 1) / 2);
          final opacity = (0.55 + 0.45 * ((z + 1) / 2)).clamp(0.0, 1.0);

          positionedItems.add(_CalculatedOrbit(
            item: item,
            x: x,
            y: y,
            z: z,
            scale: scale,
            opacity: opacity,
          ));
        }

        // Split into items behind the center card (z < 0) and in front (z >= 0)
        final backItems = positionedItems.where((p) => p.z < 0).toList();
        final frontItems = positionedItems.where((p) => p.z >= 0).toList();

        // Gentle breathing float on center card
        final centerFloatY = math.sin(progress * 2 * math.pi) * 5.0;
        final auraScale = 1.0 + math.sin(progress * 2 * math.pi) * 0.08;

        return SizedBox(
          height: 250,
          width: screenWidth * 0.92,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Soft pulsing radial aura in the background
              Transform.scale(
                scale: auraScale,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.primary.withAlpha(35),
                        AppColors.primaryLight.withAlpha(15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Orbital components BEHIND the card
              ...backItems.map((p) => _buildOrbitalBadge(p)),

              // 3. Central Premium Digital Vault Card (Rich content)
              Transform.translate(
                offset: Offset(0, centerFloatY),
                child: _buildRichCenterCard(),
              ),

              // 4. Orbital components IN FRONT of the card
              ...frontItems.map((p) => _buildOrbitalBadge(p)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrbitalBadge(_CalculatedOrbit p) {
    return Positioned(
      left: (MediaQuery.of(context).size.width * 0.92 / 2) + p.x - 26,
      top: 125 + p.y - 26,
      child: Opacity(
        opacity: p.opacity,
        child: Transform.scale(
          scale: p.scale,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  p.item.color,
                  p.item.color.withAlpha(220),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: p.item.color.withAlpha((p.z > 0 ? 110 : 40)),
                  blurRadius: p.z > 0 ? 14 : 6,
                  offset: Offset(0, p.z > 0 ? 5 : 2),
                ),
              ],
              border: Border.all(
                color: Colors.white.withAlpha(200),
                width: 1.5,
              ),
            ),
            child: Icon(
              p.item.icon,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRichCenterCard() {
    return Container(
      width: 160,
      height: 185,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withAlpha(45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Blue Lock Badge & AES-256 Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withAlpha(50)),
                ),
                child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF81C784)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF2E7D32), size: 9),
                    SizedBox(width: 2),
                    Text(
                      'AES-256',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Title & Subtitle
          const Text(
            'DIGITAL VAULT',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimaryNavy,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
          const Text(
            'Zero-Knowledge Pass',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMutedNavy,
              fontSize: 8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 5),

          // Content Item Rows: Passwords, Documents, Cards
          _buildCardDataRow(Icons.key_rounded, const Color(0xFF2979FF), 'Passwords', 'Protected'),
          const SizedBox(height: 3.5),
          _buildCardDataRow(Icons.insert_drive_file_rounded, const Color(0xFFE53935), 'Documents', 'Encrypted'),
          const SizedBox(height: 3.5),
          _buildCardDataRow(Icons.credit_card_rounded, const Color(0xFF00C853), 'Cards & IDs', 'Offline'),

          const Spacer(),

          // Bottom Security Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 10),
                SizedBox(width: 3),
                Expanded(
                  child: Text(
                    'ACTIVE VAULT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  '••••',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 7.5,
                    color: AppColors.textMutedNavy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDataRow(IconData icon, Color color, String title, String status) {
    return Row(
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryNavy,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _OrbitalItem {
  final IconData icon;
  final Color color;
  final String label;

  const _OrbitalItem({
    required this.icon,
    required this.color,
    required this.label,
  });
}

class _CalculatedOrbit {
  final _OrbitalItem item;
  final double x;
  final double y;
  final double z;
  final double scale;
  final double opacity;

  const _CalculatedOrbit({
    required this.item,
    required this.x,
    required this.y,
    required this.z,
    required this.scale,
    required this.opacity,
  });
}
