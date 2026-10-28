import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppConstants {
  // BACKEND CONFIGURATION (Cloudflare Primary with Render Fallback)
  static String cloudflarePrimaryUrl = 'https://sru-cloudflare-backend.nithwik-ui.workers.dev';
  static const String renderFallbackUrl = 'https://table-ij9g.onrender.com';
  static String get apiBaseUrl => cloudflarePrimaryUrl;
  static const String currentVersion = '3.1.1';
  static const String githubRepo = 'nithwik-ui/table';
  static const String fcmVapidKey = 'BLfXNackp6Rs_phEfbaIPWdKm7HADbl3RYGEhjU2qocshKk7CbeIX0Gb5zLQ9EH84nkSaZSiJCcENw4wWf7e12M';
  
  // DESIGN PALETTE (Academic Precision & SRU Brand)
  static const Color background = Color(0xFFF8FAFC); // Clean Slate-50 background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF003870); // SRU Brand Navy Blue
  static const Color primaryContainer = Color(0xFF0B4F96); // Accent Blue
  static const Color primaryLight = Color(0xFF1D4ED8); // Bright Blue
  static const Color primaryDark = Color(0xFF002244); // Deep Navy
  static const Color primarySoft = Color(0xFFEFF6FF); // Soft Blue 50
  static const Color onPrimary = Color(0xFFFFFFFF);
  
  // HIGH-CONTRAST NEUTRALS (Confident & legible)
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900: High-contrast ink neutral
  static const Color textSecondary = Color(0xFF475569); // Slate 600: Readable secondary metadata
  static const Color textMuted = Color(0xFF64748B); // Slate 500: Tertiary metadata / labels
  static const Color textSubtle = Color(0xFF94A3B8); // Slate 400: Dividers / subtle icons
  
  static const Color outline = Color(0xFFE2E8F0); // Slate 200: Crisp modern borders
  static const Color outlineVariant = Color(0xFFF1F5F9); // Slate 100
  static const Color secondaryContainer = Color(0xFFF1F5F9);
  static const Color onSecondaryContainer = Color(0xFF334155);
  
  // SEMANTIC STATES
  static const Color error = Color(0xFFDC2626); // Red 600
  static const Color errorContainer = Color(0xFFFEF2F2); // Red 50
  static const Color errorText = Color(0xFFB91C1C); // Red 700

  static const Color success = Color(0xFF059669); // Emerald 600
  static const Color successContainer = Color(0xFFECFDF5); // Emerald 50
  static const Color successText = Color(0xFF047857); // Emerald 700

  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color warningContainer = Color(0xFFFFFBEB); // Amber 50
  static const Color warningText = Color(0xFFB45309); // Amber 700

  static const Color info = Color(0xFF2563EB); // Blue 600
  static const Color infoContainer = Color(0xFFEFF6FF); // Blue 50
  static const Color infoText = Color(0xFF1D4ED8); // Blue 700

  static const Color purpleAccent = Color(0xFF7C3AED); // Purple 600
  static const Color purpleContainer = Color(0xFFF5F3FF); // Purple 50
  static const Color purpleText = Color(0xFF6D28D9); // Purple 700

  // SEMANTIC CLASS TYPES (Left Accent + Badge Pairs)
  // Lecture: SRU Blue
  static const Color lectureAccent = Color(0xFF003870);
  static const Color lectureBg = Color(0xFFEFF6FF);
  static const Color lectureText = Color(0xFF1D4ED8);

  // Lab: Emerald/Teal
  static const Color labAccent = Color(0xFF0D9488);
  static const Color labBg = Color(0xFFF0FDFA);
  static const Color labText = Color(0xFF0F766E);

  // Tutorial: Purple
  static const Color tutorialAccent = Color(0xFF7C3AED);
  static const Color tutorialBg = Color(0xFFF5F3FF);
  static const Color tutorialText = Color(0xFF6D28D9);

  // Practical: Warm Amber
  static const Color practicalAccent = Color(0xFFD97706);
  static const Color practicalBg = Color(0xFFFFFBEB);
  static const Color practicalText = Color(0xFFB45309);

  // Exam / Test: Crimson
  static const Color examAccent = Color(0xFFDC2626);
  static const Color examBg = Color(0xFFFEF2F2);
  static const Color examText = Color(0xFFB91C1C);

  // SEMANTIC CLASS STATUS
  // Completed: Soft Emerald
  static const Color completedAccent = Color(0xFF10B981);
  static const Color completedBg = Color(0xFFECFDF5);
  static const Color completedText = Color(0xFF047857);

  // Ongoing (Now): Primary SRU Blue
  static const Color ongoingAccent = Color(0xFF003870);
  static const Color ongoingBg = Color(0xFF003870);
  static const Color ongoingText = Color(0xFFFFFFFF);

  // Upcoming / Scheduled: Soft Indigo Blue
  static const Color upcomingAccent = Color(0xFF2563EB);
  static const Color upcomingBg = Color(0xFFEFF6FF);
  static const Color upcomingText = Color(0xFF1D4ED8);

  // Cancelled: Soft Red
  static const Color cancelledAccent = Color(0xFFEF4444);
  static const Color cancelledBg = Color(0xFFFEF2F2);
  static const Color cancelledText = Color(0xFFDC2626);

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
  static TextStyle getDisplay({Color color = textPrimary}) => _fontInter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle getHeadline({Color color = textPrimary, double? height}) => _fontInter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
        height: height,
      );

  static TextStyle getBodyLarge({Color color = textPrimary}) => _fontInter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: color,
      );

  static TextStyle getBodyMedium({Color color = textPrimary}) => _fontInter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: color,
      );

  static TextStyle getLabelSmall({Color color = textSecondary}) => _fontSpaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle getMonoLabel({Color color = textPrimary}) => _fontSpaceMono(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: color,
      );

  // ELEVATION AND RADII
  static const double radiusButton = 12.0;
  static const double radiusCard = 16.0;
  static const double radiusTag = 6.0;

  static const List<BoxShadow> shadowLevel1 = [
    BoxShadow(
      color: Color(0x0A0F172A), // rgba(15, 23, 42, 0.04)
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: Color(0x050F172A), // rgba(15, 23, 42, 0.02)
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  static const List<BoxShadow> shadowLevel2 = [
    BoxShadow(
      color: Color(0x12003870), // Subtle SRU blue elevation for selected/featured items
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
