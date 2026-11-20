import 'dart:math' as math;
import 'package:flutter/material.dart';

/// What sits behind the MyVault mark.
enum VaultMarkBackground {
  /// The mark alone (e.g. on an existing tile).
  none,

  /// Brand-gradient rounded square (legacy launcher icon, web icon, splash).
  roundedTile,

  /// Brand-gradient circle (round launcher icon).
  circle,

  /// Brand gradient filling the whole canvas (adaptive-icon background, iOS, store icon:
  /// the platform applies its own mask).
  fullBleed,
}

/// The MyVault logo: a shield with a keyhole, on the brand blue gradient.
///
/// This painter is the single source of the logo. The in-app logo uses it directly, and
/// `tool/generate_app_icons.dart` renders every launcher, store, web and iOS icon from it,
/// so they always match.
class VaultMarkPainter extends CustomPainter {
  final VaultMarkBackground background;

  /// Height of the shield as a fraction of the canvas height.
  final double markScale;

  /// Draws the shield as one flat colour with the keyhole cut out (Android themed icons).
  final bool monochrome;
  final Color monochromeColor;

  /// Soft shadow under the shield (off for monochrome and very small sizes).
  final bool shadow;

  /// False paints only the background (the adaptive icon's background layer).
  final bool drawMark;

  const VaultMarkPainter({
    this.background = VaultMarkBackground.none,
    this.markScale = 0.56,
    this.monochrome = false,
    this.monochromeColor = Colors.white,
    this.shadow = true,
    this.drawMark = true,
  });

  // Brand colours.
  static const Color gradientStart = Color(0xFF2196F3);
  static const Color gradientEnd = Color(0xFF0D47A1);
  static const Color shieldLight = Color(0xFFFFFFFF);
  static const Color shieldShade = Color(0xFFDCE9FC);
  static const Color keyholeTop = Color(0xFF1565C0);
  static const Color keyholeBottom = Color(0xFF0B3C8C);

  /// Shield outline in a 100 x 100 design space (SVG-style commands, shared with the SVG
  /// export in tool/generate_app_icons.dart).
  static const List<(String, List<double>)> shieldCommands = [
    ('M', [50, 5]),
    ('C', [60, 12, 73, 16, 87, 17]),
    ('C', [88.5, 17.1, 89.5, 18.3, 89.5, 19.8]),
    ('L', [89.5, 45]),
    ('C', [89.5, 70, 73, 86.5, 51.2, 95.3]),
    ('C', [50.4, 95.6, 49.6, 95.6, 48.8, 95.3]),
    ('C', [27, 86.5, 10.5, 70, 10.5, 45]),
    ('L', [10.5, 19.8]),
    ('C', [10.5, 18.3, 11.5, 17.1, 13, 17]),
    ('C', [27, 16, 40, 12, 50, 5]),
    ('Z', []),
  ];

  /// Keyhole: a circle over a slot that widens slightly towards its rounded base.
  static const double keyholeCx = 50, keyholeCy = 41.5, keyholeR = 10.5;
  static const List<(String, List<double>)> keyholeSlotCommands = [
    ('M', [45.6, 46]),
    ('L', [54.4, 46]),
    ('L', [56.6, 66.2]),
    ('C', [56.8, 68.1, 55.5, 69.5, 53.6, 69.5]),
    ('L', [46.4, 69.5]),
    ('C', [44.5, 69.5, 43.2, 68.1, 43.4, 66.2]),
    ('Z', []),
  ];

  /// Vertical extent of the shield in design units (its visual centre is placed on the
  /// canvas centre).
  static const double _shieldTop = 5, _shieldBottom = 95.6;

  static Path pathFrom(List<(String, List<double>)> commands) {
    final path = Path();
    for (final (op, v) in commands) {
      switch (op) {
        case 'M':
          path.moveTo(v[0], v[1]);
        case 'L':
          path.lineTo(v[0], v[1]);
        case 'C':
          path.cubicTo(v[0], v[1], v[2], v[3], v[4], v[5]);
        case 'Z':
          path.close();
      }
    }
    return path;
  }

  static Path get shieldPath => pathFrom(shieldCommands);

  static Path get keyholePath => Path.combine(
        PathOperation.union,
        Path()..addOval(Rect.fromCircle(center: const Offset(keyholeCx, keyholeCy), radius: keyholeR)),
        pathFrom(keyholeSlotCommands),
      );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final side = math.min(size.width, size.height);

    if (!monochrome) _paintBackground(canvas, rect, side);
    if (!drawMark) return;

    // Map the 100-unit design space so the shield is centred and markScale tall.
    final k = side * markScale / (_shieldBottom - _shieldTop);
    canvas.save();
    canvas.translate(
      rect.center.dx - 50 * k,
      rect.center.dy - (_shieldTop + _shieldBottom) / 2 * k,
    );
    canvas.scale(k);

    final shield = shieldPath;
    final keyhole = keyholePath;

    if (monochrome) {
      canvas.drawPath(
        Path.combine(PathOperation.difference, shield, keyhole),
        Paint()..color = monochromeColor,
      );
      canvas.restore();
      return;
    }

    if (shadow) {
      canvas.drawPath(
        shield.shift(const Offset(0, 2.2)),
        Paint()
          ..color = const Color(0xFF041B44).withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
      );
    }

    // Two-tone shield: light left half, softly shaded right half.
    canvas.save();
    canvas.clipPath(shield);
    canvas.drawRect(const Rect.fromLTRB(0, 0, 50, 100), Paint()..color = shieldLight);
    canvas.drawRect(const Rect.fromLTRB(50, 0, 100, 100), Paint()..color = shieldShade);
    canvas.restore();

    canvas.drawPath(
      keyhole,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [keyholeTop, keyholeBottom],
        ).createShader(const Rect.fromLTRB(39, 31, 61, 70)),
    );
    canvas.restore();
  }

  void _paintBackground(Canvas canvas, Rect rect, double side) {
    final Path shape;
    switch (background) {
      case VaultMarkBackground.none:
        return;
      case VaultMarkBackground.fullBleed:
        shape = Path()..addRect(rect);
      case VaultMarkBackground.roundedTile:
        final tile = Rect.fromCenter(center: rect.center, width: side * 0.92, height: side * 0.92);
        shape = Path()..addRRect(RRect.fromRectAndRadius(tile, Radius.circular(tile.width * 0.225)));
      case VaultMarkBackground.circle:
        shape = Path()..addOval(Rect.fromCenter(center: rect.center, width: side * 0.92, height: side * 0.92));
    }
    final bounds = shape.getBounds();
    canvas.drawPath(shape, Paint()..shader = brandGradient.createShader(bounds));
    // Soft light from the top-left for a little depth.
    canvas.save();
    canvas.clipPath(shape);
    canvas.drawCircle(
      bounds.topLeft + Offset(bounds.width * 0.18, bounds.height * 0.12),
      bounds.width * 0.75,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.20), Colors.white.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(
          center: bounds.topLeft + Offset(bounds.width * 0.18, bounds.height * 0.12),
          radius: bounds.width * 0.75,
        )),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(VaultMarkPainter oldDelegate) =>
      oldDelegate.background != background ||
      oldDelegate.markScale != markScale ||
      oldDelegate.monochrome != monochrome ||
      oldDelegate.monochromeColor != monochromeColor ||
      oldDelegate.shadow != shadow ||
      oldDelegate.drawMark != drawMark;
}

/// The MyVault logo as a widget.
class VaultMark extends StatelessWidget {
  final double size;
  final VaultMarkBackground background;
  final double markScale;

  const VaultMark({
    super.key,
    this.size = 64,
    this.background = VaultMarkBackground.roundedTile,
    this.markScale = 0.56,
  });

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: VaultMarkPainter(background: background, markScale: markScale, shadow: size >= 32),
        ),
      );
}
