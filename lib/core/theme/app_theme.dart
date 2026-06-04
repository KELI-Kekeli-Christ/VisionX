import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette & thème global — style sombre Glassmorphism premium.
class AppTheme {
  AppTheme._();

  // ── Couleurs ─────────────────────────────────────────────────
  static const Color bg = Color(0xFF070B14);
  static const Color surface = Color(0xFF0D1424);
  static const Color card = Color(0xFF111827);

  static const Color neon = Color(0xFF00E5FF);       // cyan accent principal
  static const Color neonGlow = Color(0x4400E5FF);   // glow translucide
  static const Color neonSoft = Color(0x2200E5FF);

  static const Color success = Color(0xFF00FFB2);
  static const Color warning = Color(0xFFFFB347);
  static const Color error = Color(0xFFFF4B6E);

  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8899BB);
  static const Color textDisabled = Color(0xFF3A4560);

  static const Color glassBorder = Color(0xFF1E2D50);
  static const Color glassWhite = Color(0x0DFFFFFF);

  // ── Bounding-box couleurs par confiance ─────────────────────
  static Color bbColor(double confidence) {
    if (confidence >= 0.75) return success;
    if (confidence >= 0.5) return neon;
    return warning;
  }

  // ── Thème principal ──────────────────────────────────────────
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        surface: surface,
        primary: neon,
        secondary: success,
        error: error,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -1,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 13,
          color: textSecondary,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textPrimary,
          letterSpacing: 0.4,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: neon,
        inactiveTrackColor: glassBorder,
        thumbColor: neon,
        overlayColor: neonSoft,
        trackHeight: 3,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  // ── Décoration carte Glassmorphism ───────────────────────────
  static BoxDecoration glassCard({
    double borderRadius = 20,
    Color borderColor = glassBorder,
  }) {
    return BoxDecoration(
      color: glassWhite,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1),
      boxShadow: [
        BoxShadow(
          color: neonGlow,
          blurRadius: 24,
          spreadRadius: -4,
        ),
      ],
    );
  }
}
