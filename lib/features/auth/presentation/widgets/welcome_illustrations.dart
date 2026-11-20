import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/brand/vault_mark.dart';
import '../../../../core/constants/app_colors.dart';

/// Shared looping-animation plumbing: controllers loop only while [animate] is true,
/// so tests and "reduce motion" users get a still frame.
mixin _LoopingIllustration<T extends StatefulWidget> on State<T>, TickerProviderStateMixin<T> {
  final List<(AnimationController, bool)> _loops = [];

  AnimationController loop(Duration duration, {bool reverse = false, double start = 0}) {
    final controller = AnimationController(vsync: this, duration: duration, value: start);
    _loops.add((controller, reverse));
    return controller;
  }

  void syncLoops(bool animate) {
    for (final (controller, reverse) in _loops) {
      if (animate && !controller.isAnimating) {
        controller.repeat(reverse: reverse);
      } else if (!animate) {
        controller.stop();
      }
    }
  }

  @override
  void dispose() {
    for (final (controller, _) in _loops) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Vault core with the six real vault categories orbiting it in 3D.
class VaultOrbitIllustration extends StatefulWidget {
  final double size;
  final bool animate;

  const VaultOrbitIllustration({super.key, required this.size, this.animate = true});

  @override
  State<VaultOrbitIllustration> createState() => _VaultOrbitIllustrationState();
}

class _VaultOrbitIllustrationState extends State<VaultOrbitIllustration>
    with TickerProviderStateMixin, _LoopingIllustration {
  late final AnimationController _orbit;
  late final AnimationController _pulse;
  late final AnimationController _ring;

  static const _items = [
    (Icons.key_rounded, AppColors.categoryPasswords),
    (Icons.badge_rounded, AppColors.categoryIdCards),
    (Icons.description_rounded, AppColors.categoryDocuments),
    (Icons.photo_rounded, AppColors.categoryPhotos),
    (Icons.sticky_note_2_rounded, AppColors.categoryNotes),
    (Icons.person_rounded, AppColors.categoryContacts),
  ];

  @override
  void initState() {
    super.initState();
    _orbit = loop(const Duration(seconds: 18), start: 0.08);
    _pulse = loop(const Duration(milliseconds: 2800), reverse: true, start: 0.5);
    _ring = loop(const Duration(seconds: 7));
    syncLoops(widget.animate);
  }

  @override
  void didUpdateWidget(VaultOrbitIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncLoops(widget.animate);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rx = size * 0.42;
    final ry = size * 0.17;
    final badge = size * 0.155;
    final core = size * 0.34;
    final height = size * 0.8; // the orbit is wide and flat: no need for a square box

    return SizedBox(
      width: size,
      height: height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_orbit, _pulse, _ring]),
        builder: (context, _) {
          final base = _orbit.value * 2 * math.pi;
          final positioned = <(double, Widget)>[];
          for (var i = 0; i < _items.length; i++) {
            final angle = base + i * 2 * math.pi / _items.length;
            final depth = math.sin(angle); // -1 back … 1 front
            final t = (depth + 1) / 2;
            final scale = 0.72 + 0.34 * t;
            final (icon, color) = _items[i];
            positioned.add((
              depth,
              Positioned(
                left: size / 2 + rx * math.cos(angle) - badge / 2,
                top: height / 2 + ry * depth - badge / 2 + size * 0.04,
                child: Opacity(
                  opacity: 0.5 + 0.5 * t,
                  child: Transform.scale(
                    scale: scale,
                    child: _OrbitBadge(size: badge, icon: icon, color: color, isDark: isDark, lift: t),
                  ),
                ),
              ),
            ));
          }
          positioned.sort((a, b) => a.$1.compareTo(b.$1));
          final back = positioned.where((p) => p.$1 < 0).map((p) => p.$2);
          final front = positioned.where((p) => p.$1 >= 0).map((p) => p.$2);
          final floatY = math.sin(_pulse.value * math.pi) * 4 - 2;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Breathing glow
              Container(
                width: size * (0.78 + 0.06 * _pulse.value),
                height: size * (0.78 + 0.06 * _pulse.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.primaryAccent.withAlpha(isDark ? 70 : 45),
                    AppColors.primaryAccent.withAlpha(0),
                  ]),
                ),
              ),
              // Orbit path
              Transform.translate(
                offset: Offset(0, size * 0.04),
                child: CustomPaint(
                  size: Size(rx * 2, ry * 2),
                  painter: _EllipsePainter(color: AppColors.primaryAccent.withAlpha(isDark ? 70 : 50)),
                ),
              ),
              ...back,
              // Vault core
              Transform.translate(
                offset: Offset(0, floatY),
                child: SizedBox.square(
                  dimension: core * 1.32,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.rotate(
                        angle: _ring.value * 2 * math.pi,
                        child: CustomPaint(
                          size: Size.square(core * 1.32),
                          painter: _SweepRingPainter(strokeWidth: core * 0.045),
                        ),
                      ),
                      _VaultCore(size: core),
                    ],
                  ),
                ),
              ),
              ...front,
            ],
          );
        },
      ),
    );
  }
}

class _OrbitBadge extends StatelessWidget {
  final double size;
  final IconData icon;
  final Color color;
  final bool isDark;
  final double lift;

  const _OrbitBadge({
    required this.size,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.lift,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withAlpha(isDark ? 90 : 40), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha((30 + 60 * lift).round()),
            blurRadius: 8 + 14 * lift,
            offset: Offset(0, 3 + 6 * lift),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class _VaultCore extends StatelessWidget {
  final double size;

  const _VaultCore({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2563EB).withAlpha(110), blurRadius: 28, offset: const Offset(0, 12)),
        ],
        border: Border.all(color: Colors.white.withAlpha(220), width: size * 0.04),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glass highlight
          Positioned(
            top: size * 0.08,
            child: Container(
              width: size * 0.55,
              height: size * 0.28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withAlpha(70), Colors.white.withAlpha(0)],
                ),
              ),
            ),
          ),
          // The app's logo mark (as on the launcher icon) rather than a generic lock.
          SizedBox.square(
            dimension: size,
            child: CustomPaint(painter: VaultMarkPainter(markScale: 0.5, shadow: size >= 48)),
          ),
        ],
      ),
    );
  }
}

class _EllipsePainter extends CustomPainter {
  final Color color;

  _EllipsePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_EllipsePainter oldDelegate) => oldDelegate.color != color;
}

/// A glowing comet-tail arc that rotates around the vault core.
class _SweepRingPainter extends CustomPainter {
  final double strokeWidth;

  _SweepRingPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth);
    canvas.drawArc(
      rect,
      0,
      math.pi * 1.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..shader = SweepGradient(
          endAngle: math.pi * 1.4,
          colors: [
            const Color(0xFF60A5FA).withAlpha(0),
            const Color(0xFF60A5FA),
            const Color(0xFFA78BFA),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SweepRingPainter oldDelegate) => oldDelegate.strokeWidth != strokeWidth;
}

/// Shield inside counter-rotating rings, with the three privacy guarantees floating around it.
class ShieldIllustration extends StatefulWidget {
  final double size;
  final bool animate;

  const ShieldIllustration({super.key, required this.size, this.animate = true});

  @override
  State<ShieldIllustration> createState() => _ShieldIllustrationState();
}

class _ShieldIllustrationState extends State<ShieldIllustration>
    with TickerProviderStateMixin, _LoopingIllustration {
  late final AnimationController _spin;
  late final AnimationController _bob;
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _spin = loop(const Duration(seconds: 16));
    _bob = loop(const Duration(milliseconds: 3200), reverse: true, start: 0.5);
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    syncLoops(widget.animate);
    widget.animate ? _enter.forward() : _enter.value = 1;
  }

  @override
  void didUpdateWidget(ShieldIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncLoops(widget.animate);
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chips = [
      (Icons.enhanced_encryption_rounded, 'AES-256', const Alignment(-0.95, -0.62), AppColors.categoryPasswords),
      (Icons.wifi_off_rounded, 'Works offline', const Alignment(1.0, -0.05), AppColors.success),
      (Icons.phone_android_rounded, 'On-device', const Alignment(-0.82, 0.7), AppColors.categoryNotes),
    ];

    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_spin, _bob, _enter]),
        builder: (context, _) {
          final spin = _spin.value * 2 * math.pi;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.8,
                height: size * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    AppColors.success.withAlpha(isDark ? 60 : 40),
                    AppColors.success.withAlpha(0),
                  ]),
                ),
              ),
              Transform.rotate(
                angle: spin,
                child: CustomPaint(
                  size: Size.square(size * 0.78),
                  painter: _DashedRingPainter(color: AppColors.primaryAccent.withAlpha(90), dashes: 36),
                ),
              ),
              Transform.rotate(
                angle: -spin * 1.6,
                child: CustomPaint(
                  size: Size.square(size * 0.6),
                  painter: _DashedRingPainter(color: AppColors.success.withAlpha(110), dashes: 22, dot: true),
                ),
              ),
              Transform.translate(
                offset: Offset(0, math.sin(_bob.value * math.pi) * 5 - 2.5),
                child: _ShieldCore(size: size * 0.4),
              ),
              for (var i = 0; i < chips.length; i++)
                _staggered(
                  index: i,
                  child: Align(
                    alignment: chips[i].$3,
                    child: Transform.translate(
                      offset: Offset(0, math.sin((_bob.value + i * 0.33) * math.pi) * 4),
                      child: _FeatureChip(icon: chips[i].$1, label: chips[i].$2, color: chips[i].$4, isDark: isDark),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _staggered({required int index, required Widget child}) {
    final start = 0.25 + index * 0.18;
    final t = Curves.easeOutBack.transform(
      ((_enter.value - start) / 0.45).clamp(0.0, 1.0),
    );
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
    );
  }
}

class _ShieldCore extends StatelessWidget {
  final double size;

  const _ShieldCore({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF34D399), Color(0xFF059669), Color(0xFF065F46)],
            ).createShader(rect),
            child: Icon(Icons.shield_rounded, size: size, color: Colors.white),
          ),
          Padding(
            padding: EdgeInsets.only(bottom: size * 0.06),
            child: Icon(Icons.lock_rounded, size: size * 0.36, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _FeatureChip({required this.icon, required this.label, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(isDark ? 90 : 45)),
        boxShadow: [
          BoxShadow(color: color.withAlpha(40), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: AppColors.textPrimaryNavy,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  final int dashes;
  final bool dot;

  _DashedRingPainter({required this.color, required this.dashes, this.dot = false});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    final step = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * step, step * 0.45, false, paint);
    }
    if (dot) {
      canvas.drawCircle(
        Offset(rect.right, rect.center.dy),
        4,
        Paint()..color = color.withAlpha(255),
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.dashes != dashes;
}

/// Fingerprint card with a scanning beam and expanding ripples.
class FingerprintIllustration extends StatefulWidget {
  final double size;
  final bool animate;

  const FingerprintIllustration({super.key, required this.size, this.animate = true});

  @override
  State<FingerprintIllustration> createState() => _FingerprintIllustrationState();
}

class _FingerprintIllustrationState extends State<FingerprintIllustration>
    with TickerProviderStateMixin, _LoopingIllustration {
  late final AnimationController _scan;
  late final AnimationController _ripple;

  @override
  void initState() {
    super.initState();
    _scan = loop(const Duration(milliseconds: 2200), reverse: true, start: 0.35);
    _ripple = loop(const Duration(milliseconds: 2600), start: 0.4);
    syncLoops(widget.animate);
  }

  @override
  void didUpdateWidget(FingerprintIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncLoops(widget.animate);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = size * 0.46;
    const accent = Color(0xFF6366F1);

    return SizedBox.square(
      dimension: size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scan, _ripple]),
        builder: (context, _) {
          final scan = Curves.easeInOut.transform(_scan.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Builder(builder: (context) {
                  final t = (_ripple.value + i / 3) % 1.0;
                  return Container(
                    width: card * (1.0 + t * 0.95),
                    height: card * (1.0 + t * 0.95),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withAlpha(((1 - t) * 90).round()), width: 1.5),
                    ),
                  );
                }),
              Container(
                width: card,
                height: card,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(card * 0.3),
                  border: Border.all(color: accent.withAlpha(isDark ? 100 : 50)),
                  boxShadow: [
                    BoxShadow(color: accent.withAlpha(60), blurRadius: 30, offset: const Offset(0, 14)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(card * 0.3),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF818CF8), Color(0xFF4F46E5), Color(0xFF7C3AED)],
                        ).createShader(rect),
                        child: Icon(Icons.fingerprint_rounded, size: card * 0.7, color: Colors.white),
                      ),
                      // Scanning beam
                      Positioned(
                        top: card * (0.12 + 0.72 * scan),
                        left: card * 0.1,
                        right: card * 0.1,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(colors: [
                              accent.withAlpha(0),
                              const Color(0xFF22D3EE),
                              accent.withAlpha(0),
                            ]),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF22D3EE).withAlpha(160), blurRadius: 12, spreadRadius: 1),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
