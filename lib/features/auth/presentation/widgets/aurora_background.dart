import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Soft, slowly drifting colour fields behind onboarding content.
/// Drawn with radial gradients (no blur filters) so it stays cheap to render.
class AuroraBackground extends StatefulWidget {
  final Widget child;
  final bool animate;

  const AuroraBackground({super.key, required this.child, this.animate = true});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
    value: 0.15,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _drift.repeat();
  }

  @override
  void didUpdateWidget(AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!widget.animate) {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _drift,
            builder: (context, _) => CustomPaint(
              painter: _AuroraPainter(t: _drift.value, isDark: isDark),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool isDark;

  _AuroraPainter({required this.t, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF0B1220), Color(0xFF0F172A)]
              : const [Color(0xFFF2F7FF), Color(0xFFFFFFFF)],
        ).createShader(rect),
    );

    final a = t * 2 * math.pi;
    final blobs = [
      (
        Offset(size.width * (0.15 + 0.12 * math.sin(a)), size.height * (0.12 + 0.05 * math.cos(a))),
        size.width * 0.85,
        isDark ? const Color(0xFF2563EB) : const Color(0xFF60A5FA),
        isDark ? 70 : 60,
      ),
      (
        Offset(size.width * (0.9 + 0.08 * math.cos(a * 1.3)), size.height * (0.35 + 0.06 * math.sin(a))),
        size.width * 0.7,
        isDark ? const Color(0xFF7C3AED) : const Color(0xFFA78BFA),
        isDark ? 55 : 45,
      ),
      (
        Offset(size.width * (0.3 + 0.1 * math.sin(a * 0.8 + 1)), size.height * (0.78 + 0.04 * math.cos(a))),
        size.width * 0.8,
        isDark ? const Color(0xFF0891B2) : const Color(0xFF67E8F9),
        isDark ? 45 : 40,
      ),
    ];

    for (final (center, radius, color, alpha) in blobs) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withAlpha(alpha), color.withAlpha(0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => oldDelegate.t != t || oldDelegate.isDark != isDark;
}
