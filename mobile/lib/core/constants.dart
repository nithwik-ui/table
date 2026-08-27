import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppConstants {
  // CONFIGURATION
  // Replace this URL with your live deployed Render REST API URL when ready.
  // When testing with local server on emulator, use 'http://10.0.2.2:3000'.
  static const String apiBaseUrl = 'https://sru-timetable-api.onrender.com';
  static const String currentVersion = '1.0.1';
  static const String githubRepo = 'Nithwik/sru-timetable';
  
  // DESIGN PALETTE (Academic Precision)
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF003870); // SRU Blue
  static const Color primaryContainer = Color(0xFF0B4F96); // Accent Blue
  static const Color onPrimary = Color(0xFFFFFFFF);
  
  static const Color textPrimary = Color(0xFF111827); // Ink Grey
  static const Color textSecondary = Color(0xFF6B7280); // Muted Grey
  
  static const Color outline = Color(0xFFE5E7EB);
  static const Color secondaryContainer = Color(0xFFDCE2F3);
  static const Color onSecondaryContainer = Color(0xFF5E6572);
  
  // SEMANTIC STATES
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF059669);
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF2563EB);
  static const Color infoContainer = Color(0xFFDBEAFE);
  static const Color purpleAccent = Color(0xFF7C3AED); // Third distinct state color (Faculty Change)
  static const Color purpleContainer = Color(0xFFF5F3FF);

  // TYPOGRAPHY (Inter & Geist-equivalent)
  static TextStyle getDisplay({Color color = textPrimary}) => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: color,
      );

  static TextStyle getHeadline({Color color = textPrimary, double? height}) => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
        height: height,
      );

  static TextStyle getBodyLarge({Color color = textPrimary}) => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: color,
      );

  static TextStyle getBodyMedium({Color color = textPrimary}) => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: color,
      );

  static TextStyle getLabelSmall({Color color = textSecondary}) => GoogleFonts.spaceMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: color,
      );

  static TextStyle getMonoLabel({Color color = textPrimary}) => GoogleFonts.spaceMono(
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
      color: Color(0x0D000000), // rgba(0, 0, 0, 0.05)
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: Color(0x08000000), // rgba(0, 0, 0, 0.03)
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const List<BoxShadow> shadowLevel2 = [
    BoxShadow(
      color: Color(0x14000000), // rgba(0, 0, 0, 0.08)
      offset: Offset(0, 10),
      blurRadius: 15,
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Color(0x08000000), // rgba(0, 0, 0, 0.03)
      offset: Offset(0, 4),
      blurRadius: 6,
      spreadRadius: -2,
    ),
  ];

  // LAYOUT
  static const double spacingBase = 8.0;
  static const double paddingContainer = 16.0;
}
