import 'package:flutter/material.dart';

/// App colour palette.
///
/// Brand and status colours are constant. Text, surface, border and pastel background colours
/// adapt to the active theme: [isDark] is updated by the app root whenever the theme
/// brightness changes (see main.dart), and the whole tree is rebuilt at that moment.
/// Theme definitions must use the fixed `light*` / `dark*` constants instead, because they
/// are built before [isDark] is known.
class AppColors {
  AppColors._();

  /// Set by the app root; true while the dark theme is active.
  static bool isDark = false;

  // Primary Blue actions
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryAccent = Color(0xFF2563EB);
  static Color get primaryLight => isDark ? const Color(0xFF1E3A5F) : const Color(0xFFE3F2FD);

  // Hero Card Gradient
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Fixed light/dark values (for ThemeData and anything that must not adapt)
  static const Color lightTextPrimary = Color(0xFF0A192F);
  static const Color lightTextSecondary = Color(0xFF1E293B);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFE2E8F0);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkBorder = Color(0xFF334155);

  // Text hierarchy (adaptive)
  static Color get textPrimaryNavy => isDark ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondaryNavy => isDark ? darkTextSecondary : lightTextSecondary;
  static Color get textMutedNavy => isDark ? darkTextMuted : lightTextMuted;
  static const Color textLight = Color(0xFFFFFFFF);

  // Surfaces & backgrounds (adaptive)
  static Color get surface => isDark ? darkSurface : Colors.white;
  static Color get background => isDark ? darkBackground : lightBackground;
  static Color get cardSurface => isDark ? darkSurface : Colors.white;

  /// Behind full-screen pages such as the dashboard and the item forms.
  static Color get canvas => isDark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FB);

  /// Bottom sheets and other panels that sit above the page.
  static Color get sheetSurface => isDark ? darkBackground : Colors.white;

  /// A quiet inset panel inside a card or sheet (info rows, list groups).
  static Color get subtleFill => isDark ? darkSurface : lightBackground;

  /// Cards inside the item forms.
  static Color get formCard => isDark ? const Color(0xFF111827) : Colors.white;
  static Color get formCardBorder => isDark ? darkSurface : const Color(0xFFE9EEF5);

  /// Unselected chips and toggles.
  static Color get chipFill => isDark ? darkSurface : const Color(0xFFF3F6FA);

  /// Primary used for icons and text on a surface: brighter in dark mode so it stays readable.
  static Color get primaryOnSurface => isDark ? const Color(0xFF60A5FA) : primary;

  /// The sheet grab handle.
  static Color get handle => isDark ? darkBorder : const Color(0xFFCBD5E1);

  // Borders & dividers (adaptive)
  static Color get border => isDark ? darkBorder : lightBorder;
  static Color get divider => isDark ? const Color(0xFF273449) : const Color(0xFFF1F5F9);

  // Gradients shared by buttons, avatars and the per-category tiles.
  static const List<Color> buttonGradient = [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)];
  static const List<Color> avatarRingGradient = [Color(0xFF60A5FA), Color(0xFFA78BFA), Color(0xFF34D399), Color(0xFF60A5FA)];
  static const List<Color> gradientBlue = [Color(0xFF60A5FA), Color(0xFF2563EB)];
  static const List<Color> gradientAmber = [Color(0xFFFBBF24), Color(0xFFEA580C)];
  static const List<Color> gradientRose = [Color(0xFFFB7185), Color(0xFFDC2626)];
  static const List<Color> gradientGreen = [Color(0xFF4ADE80), Color(0xFF16A34A)];
  static const List<Color> gradientPurple = [Color(0xFFC084FC), Color(0xFF7E22CE)];
  static const List<Color> gradientSky = [Color(0xFF38BDF8), Color(0xFF0369A1)];

  // Functional status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static Color get successLight => isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
  static Color get warningLight => isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7);
  static Color get errorLight => isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);

  // Category accents (constant) and pastel backgrounds (adaptive)
  static const Color categoryPasswords = Color(0xFF1E88E5);
  static const Color categoryIdCards = Color(0xFFFB8C00);
  static const Color categoryDocuments = Color(0xFFE53935);
  static const Color categoryPhotos = Color(0xFF43A047);
  static const Color categoryNotes = Color(0xFF8E24AA);
  static const Color categoryContacts = Color(0xFF0288D1);

  static Color get categoryPasswordsBg => isDark ? const Color(0xFF172F4F) : const Color(0xFFE3F2FD);
  static Color get categoryIdCardsBg => isDark ? const Color(0xFF3B2A14) : const Color(0xFFFFF3E0);
  static Color get categoryDocumentsBg => isDark ? const Color(0xFF3B1A1C) : const Color(0xFFFFEBEE);
  static Color get categoryPhotosBg => isDark ? const Color(0xFF16321D) : const Color(0xFFE8F5E9);
  static Color get categoryNotesBg => isDark ? const Color(0xFF2E1A3A) : const Color(0xFFF3E5F5);
  static Color get categoryContactsBg => isDark ? const Color(0xFF12304A) : const Color(0xFFE1F5FE);
}
