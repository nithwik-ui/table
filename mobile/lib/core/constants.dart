import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppConstants {
  // BACKEND CONFIGURATION (Cloudflare Primary with Render Fallback)
  static String cloudflarePrimaryUrl = 'https://sru-cloudflare-backend.nithwik-ui.workers.dev';
  static const String renderFallbackUrl = 'https://table-ij9g.onrender.com';
  static String get apiBaseUrl => cloudflarePrimaryUrl;
  static const String currentVersion = '3.1.4';
  static const String githubRepo = 'nithwik-ui/table';
  static const String fcmVapidKey =
      'BLfXNackp6Rs_phEfbaIPWdKm7HADbl3RYGEhjU2qocshKk7CbeIX0Gb5zLQ9EH84nkSaZSiJCcENw4wWf7e12M';

  /// Active theme brightness state (managed by ThemeController)
  static bool isDark = false;

  // DESIGN PALETTE (Academic Precision & SRU Brand — Light & Dark Semantic Tokens)
  static Color get background =>
      isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC);
  static Color get surface =>
      isDark ? const Color(0xFF131C31) : const Color(0xFFFFFFFF);
  static Color get surfaceElevated =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get primary =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF003870);
  static const Color brandNavy = Color(0xFF003870);
  static Color get primaryContainer =>
      isDark ? const Color(0xFF1E3A8A) : const Color(0xFF0B4F96);
  static const Color primaryLight = Color(0xFF1D4ED8);
  static const Color primaryDark = Color(0xFF002244);
  static Color get primarySoft =>
      isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // HIGH-CONTRAST NEUTRALS (Confident & legible in both Light and Dark)
  static Color get textPrimary =>
      isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary =>
      isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  static Color get textMuted =>
      isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get textSubtle =>
      isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);

  static Color get outline =>
      isDark ? const Color(0xFF26334D) : const Color(0xFFE2E8F0);
  static Color get outlineVariant =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  static Color get secondaryContainer =>
      isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  static Color get onSecondaryContainer =>
      isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155);

  // SEMANTIC STATES
  static Color get error =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get errorContainer =>
      isDark ? const Color(0xFF3F1518) : const Color(0xFFFEF2F2);
  static Color get errorText =>
      isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

  static Color get success =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
  static Color get successContainer =>
      isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
  static Color get successText =>
      isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);

  static Color get warning =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  static Color get warningContainer =>
      isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB);
  static Color get warningText =>
      isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);

  static Color get info =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  static Color get infoContainer =>
      isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF);
  static Color get infoText =>
      isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);

  static Color get purpleAccent =>
      isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  static Color get purpleContainer =>
      isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF);
  static Color get purpleText =>
      isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);

  // SEMANTIC CLASS TYPES (Left Accent + Badge Pairs)
  // Lecture: SRU Blue
  static Color get lectureAccent =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF003870);
  static Color get lectureBg =>
      isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF);
  static Color get lectureText =>
      isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);

  // Lab: Emerald/Teal
  static Color get labAccent =>
      isDark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
  static Color get labBg =>
      isDark ? const Color(0xFF134E4A) : const Color(0xFFF0FDFA);
  static Color get labText =>
      isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);

  // Tutorial: Purple
  static Color get tutorialAccent =>
      isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  static Color get tutorialBg =>
      isDark ? const Color(0xFF2E1065) : const Color(0xFFF5F3FF);
  static Color get tutorialText =>
      isDark ? const Color(0xFFC4B5FD) : const Color(0xFF6D28D9);

  // Practical: Warm Amber
  static Color get practicalAccent =>
      isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  static Color get practicalBg =>
      isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB);
  static Color get practicalText =>
      isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309);

  // Exam / Test: Crimson
  static Color get examAccent =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get examBg =>
      isDark ? const Color(0xFF3F1518) : const Color(0xFFFEF2F2);
  static Color get examText =>
      isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);

  // SEMANTIC CLASS STATUS
  // Completed: Soft Emerald
  static Color get completedAccent =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF10B981);
  static Color get completedBg =>
      isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
  static Color get completedText =>
      isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857);

  // Ongoing (Now): Primary SRU Blue
  static Color get ongoingAccent =>
      isDark ? const Color(0xFF3B82F6) : const Color(0xFF003870);
  static Color get ongoingBg =>
      isDark ? const Color(0xFF1D4ED8) : const Color(0xFF003870);
  static const Color ongoingText = Color(0xFFFFFFFF);

  // Upcoming / Scheduled: Soft Indigo Blue
  static Color get upcomingAccent =>
      isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  static Color get upcomingBg =>
      isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF);
  static Color get upcomingText =>
      isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8);

  // Cancelled: Soft Red
  static Color get cancelledAccent =>
      isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444);
  static Color get cancelledBg =>
      isDark ? const Color(0xFF3F1518) : const Color(0xFFFEF2F2);
  static Color get cancelledText =>
      isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626);

  static bool useSystemFontInTests = false;

  static TextStyle _fontInter({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    Color? color,
    double? height,
  }) {
    if (useSystemFontInTests) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
        height: height,
      );
    }
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
      height: height,
    );
  }

  static TextStyle _fontSpaceMono({
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    Color? color,
  }) {
    if (useSystemFontInTests) {
      return TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );
    }
    return GoogleFonts.spaceMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // TYPOGRAPHY (Inter & Geist-equivalent)
  static TextStyle getDisplay({Color? color}) => _fontInter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: color ?? textPrimary,
      );

  static TextStyle getHeadline({Color? color, double? height}) => _fontInter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color ?? textPrimary,
        height: height,
      );

  static TextStyle getBodyLarge({Color? color}) => _fontInter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: color ?? textPrimary,
      );

  static TextStyle getBodyMedium({Color? color}) => _fontInter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: color ?? textPrimary,
      );

  static TextStyle getLabelSmall({Color? color}) => _fontSpaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: color ?? textSecondary,
      );

  static TextStyle getMonoLabel({Color? color}) => _fontSpaceMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: color ?? textPrimary,
      );

  // ELEVATION AND RADII
  static const double radiusButton = 12.0;
  static const double radiusCard = 16.0;
  static const double radiusTag = 6.0;

  static List<BoxShadow> get shadowLevel1 => isDark
      ? const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x0A0F172A),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
          BoxShadow(
            color: Color(0x050F172A),
            offset: Offset(0, 2),
            blurRadius: 6,
          ),
        ];

  static List<BoxShadow> get shadowLevel2 => isDark
      ? const [
          BoxShadow(
            color: Color(0x4D000000),
            offset: Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x12003870),
            offset: Offset(0, 4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Color(0x080F172A),
            offset: Offset(0, 2),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ];

  // LAYOUT
  static const double spacingBase = 8.0;
  static const double paddingContainer = 16.0;
}
