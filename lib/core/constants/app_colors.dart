import 'package:flutter/material.dart';

/// App color palette matching MyVault UI design specifications:
/// - Navy typography
/// - White surfaces
/// - Blue primary actions and hero gradient
/// - Consistent pastel category accents
class AppColors {
  AppColors._();

  // Primary Blue actions
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFFE3F2FD);
  static const Color primaryAccent = Color(0xFF2563EB);

  // Hero Card Gradient
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Navy text hierarchy
  static const Color textPrimaryNavy = Color(0xFF0A192F);
  static const Color textSecondaryNavy = Color(0xFF1E293B);
  static const Color textMutedNavy = Color(0xFF64748B);
  static const Color textLight = Color(0xFFFFFFFF);

  // Surfaces & Backgrounds
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardSurface = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // Functional Status
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);

  // Category Accent Colors & Pastel Backgrounds
  static const Color categoryPasswords = Color(0xFF1E88E5);
  static const Color categoryPasswordsBg = Color(0xFFE3F2FD);

  static const Color categoryIdCards = Color(0xFFFB8C00);
  static const Color categoryIdCardsBg = Color(0xFFFFF3E0);

  static const Color categoryDocuments = Color(0xFFE53935);
  static const Color categoryDocumentsBg = Color(0xFFFFEBEE);

  static const Color categoryPhotos = Color(0xFF43A047);
  static const Color categoryPhotosBg = Color(0xFFE8F5E9);

  static const Color categoryNotes = Color(0xFF8E24AA);
  static const Color categoryNotesBg = Color(0xFFF3E5F5);

  static const Color categoryContacts = Color(0xFF0288D1);
  static const Color categoryContactsBg = Color(0xFFE1F5FE);
}
