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
    with TickerProviderStateMixin {
  late final AnimationController _orbitController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;

  // 8 orbital items for a richer circular animation
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
      icon: Icons.contacts_rounded,
      color: Color(0xFF00BCD4),
      label: 'Contacts',
    ),
    _OrbitalItem(
      icon: Icons.note_alt_rounded,
      color: Color(0xFFFF7043),
      label: 'Notes',
    ),
    _OrbitalItem(
      icon: Icons.security_rounded,
      color: Color(0xFF3F51B5),
      label: '2FA Keys',
    ),
  ];

  @override
  void initState() {
    super.initState();

    final isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
        WidgetsBinding.instance.runtimeType.toString().toLowerCase().contains('test');

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    );

    if (isTest) {
      _orbitController.value = 0.5;
      _pulseController.value = 0.5;
      _particleController.value = 0.5;
    } else {
      _orbitController.repeat();
      _pulseController.repeat(reverse: true);
      _particleController.repeat();
    }
  }

  @override
  void dispose() {
    _orbitController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
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
              const SizedBox(height: AppSpacing.sm),
              // Top shield logo
              const VaultShieldLogo(size: 72),
              const SizedBox(height: AppSpacing.xs),
              // Title
              Text(
                'MyVault',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 28,
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
                      fontSize: 12.5,
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

              // Action Button
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
    // True circular orbit radius
    final double orbitRadius = (screenWidth * 0.38).clamp(120.0, 155.0);

    return SizedBox(
      height: 340,
      width: screenWidth * 0.92,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Animated pulsing rings behind everything
          _buildPulsingRings(),

          // 2. Floating particle dots
          _buildFloatingParticles(screenWidth),

          // 3. Orbital path hint ring (subtle dashed circle)
          _buildOrbitPathRing(orbitRadius),

          // 4. Back orbital items (behind center card)
          _buildOrbitingItemsLayer(orbitRadius, screenWidth, front: false),

          // 5. Central card with floating animation
          _buildFloatingCenterCard(),

          // 6. Front orbital items (in front of center card)
          _buildOrbitingItemsLayer(orbitRadius, screenWidth, front: true),
        ],
      ),
    );
  }

  /// Pulsing concentric ring animations
  Widget _buildPulsingRings() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer ring
            Transform.scale(
              scale: 1.0 + pulse * 0.12,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withAlpha((20 + (15 * (1 - pulse))).toInt()),
                    width: 1.5,
                  ),
                ),
              ),
            ),
            // Middle ring
            Transform.scale(
              scale: 1.0 + pulse * 0.06,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withAlpha((30 + (20 * pulse)).toInt()),
                      AppColors.primaryLight.withAlpha((15 + (10 * pulse)).toInt()),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Inner glow
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withAlpha((25 + (15 * pulse)).toInt()),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Tiny floating particle dots that orbit slowly
  Widget _buildFloatingParticles(double screenWidth) {
    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final progress = _particleController.value;
        final centerX = screenWidth * 0.92 / 2;
        const centerY = 170.0;

        // 12 particles at different radii and speeds
        final particles = <Widget>[];
        for (int i = 0; i < 12; i++) {
          final radius = 60.0 + (i * 15.0) % 100;
          final speed = 1.0 + (i % 3) * 0.5;
          final angle = progress * 2 * math.pi * speed + (i * math.pi / 6);
          final x = centerX + radius * math.cos(angle) - 2;
          final y = centerY + radius * math.sin(angle) * 0.7 - 2;
          final alpha = (0.15 + 0.25 * math.sin(progress * 2 * math.pi + i)).clamp(0.0, 1.0);

          particles.add(
            Positioned(
              left: x,
              top: y,
              child: Container(
                width: 3 + (i % 3).toDouble(),
                height: 3 + (i % 3).toDouble(),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: [
                    AppColors.primary,
                    const Color(0xFF8E24AA),
                    const Color(0xFF00BCD4),
                    const Color(0xFFFFA000),
                  ][i % 4]
                      .withAlpha((alpha * 255).toInt()),
                ),
              ),
            ),
          );
        }
        return Stack(children: particles);
      },
    );
  }

  /// Subtle orbit path circle
  Widget _buildOrbitPathRing(double radius) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        return CustomPaint(
          size: Size(radius * 2 + 20, radius * 2 + 20),
          painter: _OrbitPathPainter(
            radius: radius,
            opacity: 0.08 + pulse * 0.04,
          ),
        );
      },
    );
  }

  /// Orbiting items — renders only back (z<0) or front (z>=0) items
  Widget _buildOrbitingItemsLayer(double orbitRadius, double screenWidth, {required bool front}) {
    return AnimatedBuilder(
      animation: _orbitController,
      builder: (context, child) {
        final progress = _orbitController.value;
        final baseAngle = progress * 2 * math.pi;
        final centerX = screenWidth * 0.92 / 2;
        const centerY = 170.0;

        final items = <_CalculatedOrbit>[];
        for (int i = 0; i < _orbitItems.length; i++) {
          final item = _orbitItems[i];
          final angle = baseAngle + (i * 2 * math.pi / _orbitItems.length);
          final x = orbitRadius * math.cos(angle);
          final y = orbitRadius * math.sin(angle);
          final z = math.sin(angle);
          final scale = 0.72 + 0.38 * ((z + 1) / 2);
          final opacity = (0.45 + 0.55 * ((z + 1) / 2)).clamp(0.0, 1.0);

          // Filter: only items on the requested side
          if (front && z < 0) continue;
          if (!front && z >= 0) continue;

          items.add(_CalculatedOrbit(
            item: item,
            x: x,
            y: y,
            z: z,
            scale: scale,
            opacity: opacity,
          ));
        }

        // Sort by z so items further back render first
        items.sort((a, b) => a.z.compareTo(b.z));

        return Stack(
          children: items.map((p) => _buildOrbitalBadge(p, centerX, centerY)).toList(),
        );
      },
    );
  }

  Widget _buildOrbitalBadge(_CalculatedOrbit p, double centerX, double centerY) {
    const double badgeSize = 54;
    return Positioned(
      left: centerX + p.x - badgeSize / 2,
      top: centerY + p.y - badgeSize / 2,
      child: Opacity(
        opacity: p.opacity,
        child: Transform.scale(
          scale: p.scale,
          child: Container(
            width: badgeSize,
            height: badgeSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  p.item.color,
                  p.item.color.withAlpha(200),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: p.item.color.withAlpha(p.z > 0 ? 120 : 40),
                  blurRadius: p.z > 0 ? 18 : 6,
                  offset: Offset(0, p.z > 0 ? 6 : 2),
                ),
              ],
              border: Border.all(
                color: Colors.white.withAlpha(p.z > 0 ? 230 : 150),
                width: 2.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  p.item.icon,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(height: 1),
                Text(
                  p.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 6.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Floating center card with breathing animation
  Widget _buildFloatingCenterCard() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value;
        final floatY = math.sin(pulse * math.pi) * 6.0;
        return Transform.translate(
          offset: Offset(0, floatY),
          child: _buildRichCenterCard(),
        );
      },
    );
  }

  Widget _buildRichCenterCard() {
    return Container(
      width: 170,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withAlpha(50), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(40),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Lock Badge & Secured Badge
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF81C784)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: Color(0xFF2E7D32), size: 10),
                    SizedBox(width: 2),
                    Text(
                      'Secured',
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
              fontSize: 11,
              letterSpacing: 0.6,
            ),
          ),
          const Text(
            'Private & Offline',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textMutedNavy,
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 5),

          // Content Item Rows
          _buildCardDataRow(Icons.key_rounded, const Color(0xFF2979FF), 'Passwords', 'Protected'),
          const SizedBox(height: 4),
          _buildCardDataRow(Icons.insert_drive_file_rounded, const Color(0xFFE53935), 'Documents', 'Protected'),
          const SizedBox(height: 4),
          _buildCardDataRow(Icons.credit_card_rounded, const Color(0xFF00C853), 'Cards & IDs', 'Offline'),

          const Spacer(),

          // Bottom Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 11),
                SizedBox(width: 3.5),
                Expanded(
                  child: Text(
                    'ACTIVE VAULT',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimaryNavy,
                      fontSize: 8.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  '•••• ••••',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 8.0,
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
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryNavy,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 8.0,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the subtle orbit path circle
class _OrbitPathPainter extends CustomPainter {
  final double radius;
  final double opacity;

  _OrbitPathPainter({required this.radius, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.primary.withAlpha((opacity * 255).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw dashed circle
    const dashLength = 6.0;
    const gapLength = 8.0;
    final circumference = 2 * math.pi * radius;
    final totalDashes = (circumference / (dashLength + gapLength)).floor();

    for (int i = 0; i < totalDashes; i++) {
      final startAngle = (i * (dashLength + gapLength)) / radius;
      final sweepAngle = dashLength / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPathPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
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
