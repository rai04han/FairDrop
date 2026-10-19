// ============================================================================
// FairDrop — Design System & Theme
// Based on Stitch Design Project #1184075210986276795
// ============================================================================
// Designed for outdoor glanceability under Kerala tropical sunlight.
// High contrast, light mint canvas, deep navy ink text, and dedicated
// semantic transparent-pay color anchors.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FairDropColors {
  FairDropColors._();

  // ── Core Brand Palette ─────────────────────────────────────────────────────
  static const Color brandGreen = Color(0xFF16804B); // Primary Emerald Green
  static const Color brandGreenDark = Color(0xFF006538);
  static const Color brandOrange = Color(0xFFF26A21); // Vibrant Saffron Orange
  static const Color brandNavy = Color(0xFF1B2A4A); // Primary Ink Navy
  static const Color slateMuted = Color(0xFF5E6E82); // Secondary Slate Grey
  static const Color mintBg = Color(0xFFEAF6EF); // Primary Light Mint Canvas
  static const Color mintBorder = Color(0xFFC6E7D2); // Mint Outline Border
  static const Color cardWhite = Color(0xFFFFFFFF); // Elevated Surface
  static const Color surfaceLow = Color(0xFFF1F3FF); // Low-elevation container
  static const Color surfaceContainer = Color(0xFFE9EDFF);
  static const Color surfaceHigh = Color(0xFFE1E8FF);
  static const Color surfaceHighest = Color(0xFFD9E2FF);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color warningAmber = Color(0xFFD97706); // Fuel & Weather allowance

  // ── Semantic Transparent-Pay Color Palette (Stitch Spec) ───────────────────
  // Every pay segment has an immutable, glanceable color anchor:
  static const Color payBase = Color(0xFF1B2A4A); // Base & Distance Pay (Navy)
  static const Color paySurge = Color(0xFFF26A21); // Surge / Peak (Orange)
  static const Color payWait = Color(0xFF0D9488); // Wait Time (Vivid Teal)
  static const Color payGuarantee = Color(0xFF16804B); // Wage Top-Up (Emerald)
  static const Color payAllowance = Color(0xFFD97706); // Weather/Fuel (Amber)

  // ── Ambient Box Shadows ────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    const BoxShadow(
      color: Color.fromRGBO(22, 128, 75, 0.08),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get floatingShadow => [
    const BoxShadow(
      color: Color.fromRGBO(27, 42, 74, 0.12),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

class FairDropTheme {
  FairDropTheme._();

  static ThemeData get lightTheme {
    final baseTextTheme = ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
      scaffoldBackgroundColor: FairDropColors.mintBg,
      colorScheme: ColorScheme.light(
        primary: FairDropColors.brandGreen,
        onPrimary: Colors.white,
        primaryContainer: FairDropColors.brandGreen,
        onPrimaryContainer: Colors.white,
        secondary: FairDropColors.brandOrange,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFFC7129),
        onSecondaryContainer: Colors.white,
        tertiary: FairDropColors.payWait,
        onTertiary: Colors.white,
        surface: FairDropColors.cardWhite,
        onSurface: FairDropColors.brandNavy,
        surfaceContainerLowest: FairDropColors.cardWhite,
        surfaceContainerLow: FairDropColors.surfaceLow,
        surfaceContainer: FairDropColors.surfaceContainer,
        surfaceContainerHigh: FairDropColors.surfaceHigh,
        surfaceContainerHighest: FairDropColors.surfaceHighest,
        outline: FairDropColors.slateMuted,
        outlineVariant: FairDropColors.mintBorder,
        error: FairDropColors.errorRed,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: baseTextTheme.displayLarge?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.03,
        ),
        displayMedium: baseTextTheme.displayMedium?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.02,
        ),
        displaySmall: baseTextTheme.displaySmall?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w800,
        ),
        headlineLarge: baseTextTheme.headlineLarge?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.02,
        ),
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.01,
        ),
        headlineSmall: baseTextTheme.headlineSmall?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          color: FairDropColors.slateMuted,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          color: FairDropColors.brandNavy,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.01,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          color: FairDropColors.slateMuted,
          fontWeight: FontWeight.w600,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.04,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: FairDropColors.brandNavy),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: FairDropColors.brandNavy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: FairDropColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color.fromRGBO(22, 128, 75, 0.12), width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FairDropColors.brandGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FairDropColors.brandNavy,
          side: const BorderSide(color: FairDropColors.mintBorder, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FairDropColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FairDropColors.mintBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FairDropColors.mintBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FairDropColors.brandGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FairDropColors.errorRed, width: 1.5),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: FairDropColors.slateMuted,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF94A3B8),
          fontWeight: FontWeight.w400,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: FairDropColors.cardWhite,
        selectedItemColor: FairDropColors.brandGreen,
        unselectedItemColor: FairDropColors.slateMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

/// Helper widget to render the official FairDrop wordmark
class FairDropLogo extends StatelessWidget {
  final double fontSize;
  final bool showSubtitle;

  const FairDropLogo({
    super.key,
    this.fontSize = 28,
    this.showSubtitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.plusJakartaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            children: const [
              TextSpan(
                text: 'Fair',
                style: TextStyle(color: FairDropColors.brandGreen),
              ),
              TextSpan(
                text: 'Drop',
                style: TextStyle(color: FairDropColors.brandOrange),
              ),
            ],
          ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 6),
          Text(
            'Transparent Algorithmic Pay\nfor Gig Delivery Workers',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: FairDropColors.brandNavy,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}
