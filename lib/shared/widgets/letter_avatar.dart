import 'package:flutter/material.dart';

/// A rounded tile with the first letter of [name], used for password items.
///
/// Each name gets a stable colour from a fixed palette (well-known services use their brand
/// hue), tuned so the letter stays readable in both light and dark themes.
class LetterAvatar extends StatelessWidget {
  final String name;
  final double size;

  const LetterAvatar({super.key, required this.name, this.size = 42});

  static const List<Color> _palette = [
    Color(0xFF2563EB), // blue
    Color(0xFF7C3AED), // violet
    Color(0xFFDB2777), // pink
    Color(0xFFEA580C), // orange
    Color(0xFF0D9488), // teal
    Color(0xFF16A34A), // green
    Color(0xFF4F46E5), // indigo
    Color(0xFFDC2626), // red
    Color(0xFF0891B2), // cyan
    Color(0xFFCA8A04), // amber
  ];

  /// Brand hues for common services (by lower-case name prefix).
  static const Map<String, Color> _brands = {
    'google': Color(0xFFEA4335),
    'gmail': Color(0xFFEA4335),
    'github': Color(0xFF64748B),
    'amazon': Color(0xFFFF9900),
    'netflix': Color(0xFFE50914),
    'facebook': Color(0xFF1877F2),
    'instagram': Color(0xFFE1306C),
    'whatsapp': Color(0xFF25D366),
    'linkedin': Color(0xFF0A66C2),
    'twitter': Color(0xFF1D9BF0),
    'microsoft': Color(0xFF0078D4),
    'outlook': Color(0xFF0078D4),
    'apple': Color(0xFF64748B),
    'paypal': Color(0xFF003087),
    'spotify': Color(0xFF1DB954),
  };

  static Color colorFor(String name) {
    final key = name.trim().toLowerCase();
    for (final entry in _brands.entries) {
      if (key.startsWith(entry.key)) return entry.value;
    }
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = colorFor(name);
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base.withAlpha(isDark ? 56 : 28),
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          // Lightened on dark backgrounds so dark brand hues stay readable.
          color: isDark ? Color.lerp(base, Colors.white, 0.45) : base,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.43,
        ),
      ),
    );
  }
}
