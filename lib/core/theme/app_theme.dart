import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// App theme configuring Material 3 for MyVault
class AppTheme {
  AppTheme._();

  /// Bundled in assets/fonts (OFL licensed) so the app never fetches fonts over the network.
  static const String fontFamily = 'PlusJakartaSans';

  /// Fade-and-slide page transitions on every platform for a consistent, modern feel.
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      pageTransitionsTheme: pageTransitions,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.lightTextPrimary,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.lightTextPrimary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: AppColors.lightTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 30,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
        bodyMedium: TextStyle(
          color: AppColors.lightTextMuted,
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: TextStyle(
          color: AppColors.lightTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shadowColor: AppColors.lightTextPrimary.withAlpha(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(
            color: AppColors.lightBorder,
            width: 1.0,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: _elevatedButtonTheme(AppColors.primary),
      outlinedButtonTheme: _outlinedButtonTheme(AppColors.lightTextPrimary, AppColors.lightBorder),
      textButtonTheme: _textButtonTheme,
      dialogTheme: _dialogTheme(Colors.white, AppColors.lightTextPrimary, AppColors.lightTextSecondary),
      bottomSheetTheme: _bottomSheetTheme(Colors.white),
      snackBarTheme: _snackBarTheme,
      inputDecorationTheme: inputTheme(dark: false),
    );
  }

  static ThemeData get darkTheme {
    const darkBg = AppColors.darkBackground;
    const darkSurface = AppColors.darkSurface;
    const darkCard = AppColors.darkSurface;
    const darkBorder = AppColors.darkBorder;
    const darkTextPrimary = AppColors.darkTextPrimary;
    const darkTextMuted = AppColors.darkTextMuted;

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      pageTransitionsTheme: pageTransitions,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: const Color(0xFF3B82F6),
        onPrimary: Colors.white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: darkTextPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
          side: const BorderSide(
            color: darkBorder,
            width: 1.0,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: darkTextPrimary, fontSize: 30, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: darkTextPrimary, fontSize: 24, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: darkTextPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: darkTextPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: darkTextMuted, fontSize: 13),
      ),
      elevatedButtonTheme: _elevatedButtonTheme(const Color(0xFF3B82F6)),
      outlinedButtonTheme: _outlinedButtonTheme(darkTextPrimary, darkBorder),
      textButtonTheme: _textButtonTheme,
      dialogTheme: _dialogTheme(darkSurface, darkTextPrimary, AppColors.darkTextSecondary),
      bottomSheetTheme: _bottomSheetTheme(darkBg),
      snackBarTheme: _snackBarTheme,
      inputDecorationTheme: inputTheme(dark: true),
    );
  }

  // Shared component styles. Button text styles must name the font family: a button's
  // textStyle replaces the inherited style, so without it buttons fall back to Roboto.

  static const TextStyle _buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static final RoundedRectangleBorder _buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0));

  static ElevatedButtonThemeData _elevatedButtonTheme(Color background) => ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          disabledBackgroundColor: background.withAlpha(90),
          disabledForegroundColor: Colors.white.withAlpha(170),
          elevation: 0,
          shape: _buttonShape,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14.0),
          textStyle: _buttonText,
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme(Color foreground, Color border) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          side: BorderSide(color: border, width: 1.2),
          shape: _buttonShape,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14.0),
          textStyle: _buttonText,
        ),
      );

  static final TextButtonThemeData _textButtonTheme = TextButtonThemeData(
    style: TextButton.styleFrom(
      shape: _buttonShape,
      textStyle: _buttonText.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  static DialogThemeData _dialogTheme(Color background, Color title, Color body) => DialogThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: title,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        contentTextStyle: TextStyle(fontFamily: fontFamily, color: body, fontSize: 14, height: 1.45),
      );

  static BottomSheetThemeData _bottomSheetTheme(Color background) => BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        clipBehavior: Clip.antiAlias,
      );

  static final SnackBarThemeData _snackBarTheme = SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    contentTextStyle: const TextStyle(
      fontFamily: fontFamily,
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  /// Soft filled fields with a subtle border and a clear focus ring; icons pick up the
  /// primary colour while the field is focused.
  static InputDecorationTheme inputTheme({required bool dark}) {
    final fill = dark ? AppColors.darkSurface : const Color(0xFFF6F8FB);
    final border = dark ? AppColors.darkBorder : const Color(0xFFE3E9F1);
    final focus = dark ? const Color(0xFF60A5FA) : AppColors.primary;
    OutlineInputBorder outline(Color color, [double width = 1.2]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(focus, 1.8),
      errorBorder: outline(AppColors.error),
      focusedErrorBorder: outline(AppColors.error, 1.8),
      disabledBorder: outline(border.withAlpha(120)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w500),
      prefixIconColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.focused) ? focus : const Color(0xFF94A3B8),
      ),
      suffixIconColor: const Color(0xFF94A3B8),
      errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }
}
