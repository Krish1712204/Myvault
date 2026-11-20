import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum ScannerPhase { idle, scanning, success, error }

/// Animated fingerprint sensor for the unlock screen.
///
/// idle      – slow comet ring and soft ripples
/// scanning  – faster ring and a beam sweeping the print
/// success   – ring turns green and closes, print morphs into an open lock, particles burst
/// error     – red flash and a horizontal shake
class FingerprintScanner extends StatefulWidget {
  final double size;
  final ScannerPhase phase;
  final bool animate;
  final VoidCallback? onTap;

  const FingerprintScanner({
    super.key,
    required this.size,
    required this.phase,
    this.animate = true,
    this.onTap,
  });

  @override
  State<FingerprintScanner> createState() => _FingerprintScannerState();
}

class _FingerprintScannerState extends State<FingerprintScanner> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 6));
  late final AnimationController _ripple = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  late final AnimationController _beam = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
  late final AnimationController _result = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  static const _blue = Color(0xFF3B82F6);
  static const _violet = Color(0xFF8B5CF6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _ripple.value = 0.3;
    _beam.value = 0.5;
    _apply(null);
  }

  @override
  void didUpdateWidget(FingerprintScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase || oldWidget.animate != widget.animate) _apply(oldWidget.phase);
  }

  void _apply(ScannerPhase? previous) {
    final animate = widget.animate;
    switch (widget.phase) {
      case ScannerPhase.idle:
        _spin.duration = const Duration(seconds: 6);
        if (animate) {
          _spin.repeat();
          _ripple.repeat();
        }
        _beam.stop();
        _result.value = 0;
      case ScannerPhase.scanning:
        _spin.duration = const Duration(milliseconds: 1600);
        if (animate) {
          _spin.repeat();
          _ripple.repeat();
          _beam.repeat(reverse: true);
        }
        _result.value = 0;
      case ScannerPhase.success:
        _beam.stop();
        _ripple.stop();
        animate ? _result.forward(from: 0) : _result.value = 1;
      case ScannerPhase.error:
        _beam.stop();
        if (animate) _shake.forward(from: 0);
        _result.value = 0;
    }
    if (!animate) {
      _spin.stop();
      _ripple.stop();
      _beam.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _ripple.dispose();
    _beam.dispose();
    _result.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phase = widget.phase;
    final accent = switch (phase) {
      ScannerPhase.success => _green,
      ScannerPhase.error => _red,
      _ => _blue,
    };

    return Semantics(
      button: widget.onTap != null,
      label: 'Fingerprint sensor',
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_spin, _ripple, _beam, _result, _shake]),
          builder: (context, _) {
            final shake = math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value);
            final success = Curves.easeOutBack.transform(_result.value.clamp(0.0, 1.0));
            final inner = size * 0.5;

            return Transform.translate(
              offset: Offset(shake, 0),
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Halo
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: size * 0.92,
                      height: size * 0.92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [accent.withAlpha(isDark ? 70 : 45), accent.withAlpha(0)]),
                      ),
                    ),
                    // Ripples
                    if (phase != ScannerPhase.success)
                      for (var i = 0; i < 3; i++)
                        Builder(builder: (context) {
                          final t = (_ripple.value + i / 3) % 1.0;
                          final d = inner * (1.05 + t * 0.85);
                          return Container(
                            width: d,
                            height: d,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: accent.withAlpha(((1 - t) * 110).round()), width: 1.4),
                            ),
                          );
                        }),
                    // Tick marks + comet ring
                    Transform.rotate(
                      angle: _spin.value * 2 * math.pi,
                      child: CustomPaint(
                        size: Size.square(size * 0.84),
                        painter: _CometRingPainter(
                          color: accent,
                          secondary: phase == ScannerPhase.idle || phase == ScannerPhase.scanning ? _violet : accent,
                          closeProgress: _result.value,
                        ),
                      ),
                    ),
                    CustomPaint(
                      size: Size.square(size * 0.7),
                      painter: _TickRingPainter(color: accent.withAlpha(isDark ? 110 : 80)),
                    ),
                    // Sensor disc
                    Container(
                      width: inner,
                      height: inner,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.formCard,
                        border: Border.all(color: accent.withAlpha(90), width: 1.5),
                        boxShadow: [
                          BoxShadow(color: accent.withAlpha(90), blurRadius: 30, offset: const Offset(0, 12)),
                        ],
                      ),
                      child: ClipOval(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Fingerprint (fades and shrinks on success)
                            Opacity(
                              opacity: (1 - _result.value * 1.6).clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 1 - 0.3 * _result.value,
                                child: ShaderMask(
                                  shaderCallback: (rect) => LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: phase == ScannerPhase.error
                                        ? const [Color(0xFFF87171), _red]
                                        : const [Color(0xFF60A5FA), Color(0xFF6366F1), _violet],
                                  ).createShader(rect),
                                  child: Icon(Icons.fingerprint_rounded, size: inner * 0.66, color: Colors.white),
                                ),
                              ),
                            ),
                            // Scan beam with trailing glow
                            if (phase == ScannerPhase.scanning)
                              Positioned(
                                top: inner * (0.08 + 0.78 * Curves.easeInOut.transform(_beam.value)) - inner * 0.18,
                                left: 0,
                                right: 0,
                                child: Column(
                                  children: [
                                    Container(
                                      height: inner * 0.18,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: _beam.status == AnimationStatus.reverse ? Alignment.bottomCenter : Alignment.topCenter,
                                          end: _beam.status == AnimationStatus.reverse ? Alignment.topCenter : Alignment.bottomCenter,
                                          colors: [const Color(0xFF22D3EE).withAlpha(0), const Color(0xFF22D3EE).withAlpha(60)],
                                        ),
                                      ),
                                    ),
                                    Container(
                                      height: 2.5,
                                      margin: EdgeInsets.symmetric(horizontal: inner * 0.08),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF67E8F9),
                                        boxShadow: [
                                          BoxShadow(color: const Color(0xFF22D3EE).withAlpha(200), blurRadius: 10, spreadRadius: 1),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Success: open lock
                            if (_result.value > 0)
                              Transform.scale(
                                scale: success,
                                child: Container(
                                  width: inner * 0.62,
                                  height: inner * 0.62,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [Color(0xFF34D399), _green]),
                                  ),
                                  child: Icon(Icons.lock_open_rounded, color: Colors.white, size: inner * 0.34),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Success particles
                    if (_result.value > 0)
                      CustomPaint(
                        size: Size.square(size),
                        painter: _BurstPainter(progress: _result.value, color: _green),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CometRingPainter extends CustomPainter {
  final Color color;
  final Color secondary;
  final double closeProgress;

  _CometRingPainter({required this.color, required this.secondary, required this.closeProgress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final rect = (Offset.zero & size).deflate(stroke);
    // On success the arc grows into a full circle.
    final sweep = math.pi * (1.2 + 0.8 * closeProgress);
    canvas.drawArc(
      rect,
      0,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..shader = SweepGradient(
          endAngle: math.max(sweep, 0.01),
          // Transparent outside the arc, so the rounded start cap does not pick up the end colour.
          tileMode: TileMode.decal,
          colors: [color.withAlpha((255 * closeProgress).round()), secondary, color],
        ).createShader(rect),
    );
    final head = Offset(rect.center.dx + rect.width / 2 * math.cos(sweep), rect.center.dy + rect.height / 2 * math.sin(sweep));
    canvas.drawCircle(head, 7, Paint()..color = color.withAlpha(70));
    canvas.drawCircle(head, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CometRingPainter old) =>
      old.color != color || old.secondary != secondary || old.closeProgress != closeProgress;
}

class _TickRingPainter extends CustomPainter {
  final Color color;

  _TickRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = i * 2 * math.pi / 60;
      final len = i % 5 == 0 ? 7.0 : 3.5;
      canvas.drawLine(
        Offset(c.dx + (r - len) * math.cos(a), c.dy + (r - len) * math.sin(a)),
        Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_TickRingPainter old) => old.color != color;
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final t = Curves.easeOutCubic.transform(progress);
    for (var i = 0; i < 16; i++) {
      final a = i * 2 * math.pi / 16 + (i.isEven ? 0.1 : -0.1);
      final dist = size.width * (0.26 + 0.24 * t) * (i.isEven ? 1 : 0.85);
      final radius = (i.isEven ? 4.0 : 2.6) * (1 - t * 0.6);
      canvas.drawCircle(
        Offset(c.dx + dist * math.cos(a), c.dy + dist * math.sin(a)),
        radius,
        Paint()..color = (i % 3 == 0 ? const Color(0xFF67E8F9) : color).withAlpha(((1 - t) * 255).round()),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
