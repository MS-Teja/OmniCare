import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OmniCare's "Warm Sanctuary" design system.
///
/// Light mode only — dark mode adds cognitive load for elderly users.
/// High contrast, large touch targets, warm earth tones.
class OmniCareTheme {
  OmniCareTheme._();

  // ── Palette ──────────────────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFFF8FAFC); // Slate 50 tint for modern, clean depth
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  
  // Bolder, high-energy primary (Emerald replaces Sage)
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDark = Color(0xFF047857);
  static const Color emeraldLight = Color(0xFFD1FAE5);
  
  // Bolder, high-energy secondary (Sapphire replaces Coral)
  static const Color sapphire = Color(0xFF3B82F6);
  static const Color sapphireDark = Color(0xFF1D4ED8);
  static const Color sapphireLight = Color(0xFFDBEAFE);
  
  // Extreme contrast neutrals
  static const Color slate900 = Color(0xFF0F172A); // Maximum contrast heading text
  static const Color slate500 = Color(0xFF64748B); // Secondary body text
  static const Color slate200 = Color(0xFFE2E8F0); // Dramatic, crisp borders
  
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedLight = Color(0xFFFEE2E2);

  // ── Typography ───────────────────────────────────────────────────
  static TextTheme get _textTheme {
    // Retaining Source Serif 4 for a touch of warmth and humanity, but heavily weighting it.
    final heading = GoogleFonts.sourceSerif4(color: slate900);
    final body = GoogleFonts.dmSans(color: slate900);

    return TextTheme(
      // Extreme scale jump for hero moments (from 34 to 48, w800)
      displayLarge: heading.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.5,
      ),
      displayMedium: heading.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.15,
        letterSpacing: -1.0,
      ),
      headlineLarge: heading.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineMedium: heading.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      titleLarge: body.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      titleMedium: body.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: body.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        height: 1.55,
      ),
      bodyMedium: body.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: slate500,
      ),
      labelLarge: body.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700, // Punchier labels
        height: 1.3,
        letterSpacing: 0.3,
      ),
      labelMedium: body.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelSmall: body.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: slate500,
      ),
    );
  }

  // ── ThemeData ─────────────────────────────────────────────────────
  static ThemeData get theme {
    final text = _textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: scaffoldBg,
      textTheme: text,

      colorScheme: const ColorScheme.light(
        primary: emerald,
        onPrimary: Colors.white,
        secondary: sapphire,
        onSecondary: Colors.white,
        surface: surfaceWhite,
        onSurface: slate900,
        error: errorRed,
        onError: Colors.white,
        outline: slate200,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: slate900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineMedium,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60), // Thicker button
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // More extreme rounding
          ),
          textStyle: text.labelLarge?.copyWith(color: Colors.white),
          elevation: 8,
          shadowColor: emerald.withValues(alpha: 0.4), // Dramatic tinted shadow
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slate900,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          side: const BorderSide(color: slate200, width: 2), // Bold 2px border
          textStyle: text.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: emerald,
          textStyle: text.labelLarge,
          minimumSize: const Size(48, 48),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: slate200, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: slate200, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: emerald, width: 3), // Thicker focus
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
        hintStyle: text.bodyLarge?.copyWith(color: slate500),
        errorStyle: text.bodySmall?.copyWith(color: errorRed),
      ),

      cardTheme: CardThemeData(
        color: surfaceWhite,
        elevation: 12,
        shadowColor: slate900.withValues(alpha: 0.08), // Large soft shadow
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28), // High spatial drama radiuses
          side: const BorderSide(color: slate200, width: 1.5),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: slate200,
        thickness: 1.5, // Stronger dividers
        space: 1.5,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: slate900,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
