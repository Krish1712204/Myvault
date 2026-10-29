import 'package:flutter/material.dart';

/// App color palette adhering to MyVault design requirements:
/// - Navy text
/// - White surfaces
/// - Blue primary actions
class AppColors {
  AppColors._();

  // Primary Blue actions
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFFBBDEFB);

  // Navy text hierarchy
  static const Color textPrimaryNavy = Color(0xFF0A192F);
  static const Color textSecondaryNavy = Color(0xFF1E293B);
  static const Color textMutedNavy = Color(0xFF475569);

  // Surfaces & Backgrounds
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardSurface = Color(0xFFFFFFFF);

  // Borders & Accents
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
}
