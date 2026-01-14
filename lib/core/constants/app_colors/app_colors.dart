import 'package:flutter/material.dart';

/// AppColors
/// 
/// Centralized color palette for the entire application.
/// All colors are defined as final values for consistency
/// and performance. Use these colors throughout the app instead of
/// hardcoding color values.
/// 
/// Color naming convention:
/// - Primary colors: primary, primaryLight, primaryDark
/// - Accent colors: accent, accentLight, accentDark
/// - Semantic colors: error, success, warning, info
/// - Grey scale: greyScale with variants (50, 100, 200, etc.)
/// - Background colors: background, surface, card
/// - Text colors: textPrimary, textSecondary, textTertiary

  final kickGreen = Color(0xFF42A720); // Kick Green
  final youtubeRed = Color(0xFFDD2C28); // Youtube Red
  final twitchPurple = Color(0xFFB950EF); // Twitch Purple
  final cyanBlue = Color(0xFF84DEE4); // Cyan Blue
  final beige = Color(0xFFE6C571); // Beige
  final bottomSheetGrey = Color(0xFF141212); // Beige
  final onBottomSheetGrey = Color(0xFF1E1D20);
  final golden = Color.fromRGBO(246, 246, 146, 0.25);
  final goldeffect = Color.fromRGBO(255, 230, 167, 0.25);
  final blackbox = Color.fromRGBO(35, 34, 37, 1);

final grey = Color.fromRGBO(235, 235, 245, 0.3);
  final onDark = Colors.white;
  final onLight = Colors.black;



  // Primary Colors
  final primary = Color(0xFF6366F1); // Indigo-500
  final primaryLight = Color(0xFF818CF8); // Indigo-400
  final primaryDark = Color(0xFF4F46E5); // Indigo-600
  final primaryContainer = Color(0xFFE0E7FF); // Indigo-100

  // Secondary Colors
  final secondary = Color(0xFF8B5CF6); // Purple-500
  final secondaryLight = Color(0xFFA78BFA); // Purple-400
  final secondaryDark = Color(0xFF7C3AED); // Purple-600
  final secondaryContainer = Color(0xFFEDE9FE); // Purple-100

  // Accent Colors
  final accent = Color(0xFF06B6D4); // Cyan-500
  final accentLight = Color(0xFF22D3EE); // Cyan-400
  final accentDark = Color(0xFF0891B2); // Cyan-600

  // Semantic Colors
  final error = Color(0xFFEF4444); // Red-500
  final errorLight = Color(0xFFFEE2E2); // Red-100
  final errorDark = Color(0xFFDC2626); // Red-600

  final success = Color(0xFF10B981); // Green-500
  final successLight = Color(0xFFD1FAE5); // Green-100
  final successDark = Color(0xFF059669); // Green-600

  final warning = Color(0xFFF59E0B); // Amber-500
  final warningLight = Color(0xFFFEF3C7); // Amber-100
  final warningDark = Color(0xFFD97706); // Amber-600

  final info = Color(0xFF3B82F6); // Blue-500
  final infoLight = Color(0xFFDBEAFE); // Blue-100
  final infoDark = Color(0xFF2563EB); // Blue-600

  // Grey Scale
  final greyScale50 = Color(0xFFF9FAFB);
  final greyScale100 = Color(0xFFF3F4F6);
  final greyScale200 = Color(0xFFE5E7EB);
  final greyScale300 = Color(0xFFD1D5DB);
  final greyScale400 = Color(0xFF9CA3AF);
  final greyScale500 = Color(0xFF6B7280);
  final greyScale600 = Color(0xFF4B5563);
  final greyScale700 = Color(0xFF374151);
  final greyScale800 = Color(0xFF1F2937);
  final greyScale900 = Color(0xFF111827);

  // Background Colors
  final background = Color(0xFFFFFFFF);
  final backgroundDark = Color(0xFF0F172A); // Slate-900
  final surface = Color(0xFFFFFFFF);
  final surfaceDark = Color(0xFF1E293B); // Slate-800
  final card = Color(0xFFFFFFFF);
  final cardDark = Color(0xFF334155); // Slate-700

  // Text Colors
  final textPrimary = Color(0xFF111827); // Grey-900
  final textSecondary = Color(0xFF6B7280); // Grey-500
  final textTertiary = Color(0xFF9CA3AF); // Grey-400
  final textInverse = Color(0xFFFFFFFF);
  final textDisabled = Color(0xFFD1D5DB); // Grey-300

  // Border Colors
  final border = Color(0xFFE5E7EB); // Grey-200
  final borderLight = Color(0xFFF3F4F6); // Grey-100
  final borderDark = Color(0xFFD1D5DB); // Grey-300

  // Divider Colors
  final divider = Color(0xFFE5E7EB); // Grey-200
  final dividerDark = Color(0xFF374151); // Grey-700

  // Overlay Colors
  final overlay = Color(0x80000000); // Black with 50% opacity
  final overlayLight = Color(0x40000000); // Black with 25% opacity

  // Gradient Colors
  final LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  final LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryDark],
  );

  final LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );

  final LinearGradient twitchGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color(0xFFB950EF), Color(0xFF401162)],
  );

  final LinearGradient goldGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color(0xFFFFE6A7), Color(0xFFF2B269),],
  );


