import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/ui/motion.dart';
import '../../../../shared/state/vault_insights_provider.dart';
import '../../../../shared/widgets/notifications_sheet.dart';
import '../../../../shared/widgets/pressable_scale.dart';

/// Hero card: an animated health ring, a one-line verdict, and tappable vault stats.
class VaultHealthCard extends StatefulWidget {
  final int score;
  final int totalItems;
  final int favourites;
  final int alerts;

  const VaultHealthCard({
    super.key,
    required this.score,
    required this.totalItems,
    required this.favourites,
    required this.alerts,
  });

  @override
  State<VaultHealthCard> createState() => _VaultHealthCardState();
}

class _VaultHealthCardState extends State<VaultHealthCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
    value: 0.3,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionEnabled(context)) {
      if (!_ambient.isAnimating) _ambient.repeat();
    } else {
      _ambient.stop();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final healthy = widget.score >= 90;
    final headline = widget.totalItems == 0
        ? 'Your vault is ready'
        : healthy
            ? 'Your vault is in great shape'
            : 'A few things need attention';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2563EB).withAlpha(80), blurRadius: 30, offset: const Offset(0, 14)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: AnimatedBuilder(
          animation: _ambient,
          builder: (context, child) => CustomPaint(
            painter: _HeroBackdropPainter(t: _ambient.value),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _HealthRing(score: widget.score),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(38),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withAlpha(50)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  healthy ? Icons.verified_rounded : Icons.shield_outlined,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'Vault health · ${vaultHealthLabel(widget.score)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            headline,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'AES-256 encrypted · stored only on this phone',
                            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _StatPill(
                        icon: Icons.layers_rounded,
                        value: widget.totalItems,
                        label: 'Items',
                        onTap: () => context.go('/categories'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        icon: Icons.star_rounded,
                        value: widget.favourites,
                        label: 'Starred',
                        onTap: () => context.push('/category/favourites'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatPill(
                        icon: Icons.notifications_rounded,
                        value: widget.alerts,
                        label: 'Alerts',
                        highlight: widget.alerts > 0,
                        onTap: () => NotificationsSheet.show(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthRing extends StatelessWidget {
  final int score;

  const _HealthRing({required this.score});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox.square(
          dimension: 92,
          child: CustomPaint(
            painter: _RingPainter(progress: value),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).round()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of 100',
                    style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withAlpha(40),
    );
    if (progress <= 0) return;
    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        // Starts at 12 o'clock like the arc itself.
        ..shader = const SweepGradient(
          transform: GradientRotation(-math.pi / 2),
          colors: [Color(0xFF67E8F9), Color(0xFF86EFAC), Color(0xFFFFFFFF)],
        ).createShader(rect),
    );
    // Glowing head dot
    final head = -math.pi / 2 + sweep;
    final center = rect.center;
    final r = rect.width / 2;
    final dot = Offset(center.dx + r * math.cos(head), center.dy + r * math.sin(head));
    canvas.drawCircle(dot, stroke * 0.85, Paint()..color = Colors.white.withAlpha(90));
    canvas.drawCircle(dot, stroke * 0.45, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.progress != progress;
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(highlight ? 60 : 34),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(highlight ? 110 : 45)),
        ),
        child: Row(
          children: [
            Icon(icon, color: highlight ? const Color(0xFFFDE68A) : Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: value),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      '$v',
                      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.1, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deep blue gradient with drifting light blooms and a slow diagonal sheen.
class _HeroBackdropPainter extends CustomPainter {
  final double t;

  _HeroBackdropPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF4F46E5)],
        ).createShader(rect),
    );

    final a = t * 2 * math.pi;
    for (final (center, radius, color) in [
      (Offset(size.width * (0.85 + 0.08 * math.sin(a)), size.height * (0.1 + 0.1 * math.cos(a))), size.width * 0.55, const Color(0xFF22D3EE)),
      (Offset(size.width * (0.1 + 0.1 * math.cos(a)), size.height * (0.95 + 0.08 * math.sin(a))), size.width * 0.5, const Color(0xFFA78BFA)),
    ]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color.withAlpha(75), color.withAlpha(0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    // Diagonal sheen sweeping across once per cycle
    final x = -0.6 + t * 2.2;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(x * 2 - 1.4, -1),
          end: Alignment(x * 2 - 0.6, 1),
          colors: [Colors.white.withAlpha(0), Colors.white.withAlpha(22), Colors.white.withAlpha(0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HeroBackdropPainter oldDelegate) => oldDelegate.t != t;
}
