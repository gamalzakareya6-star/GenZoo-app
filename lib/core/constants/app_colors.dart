import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppColors {
  // The brand colors follow the palette the student picked (see AppPalette).
  // In dark mode the lighter shade is used so text stays readable.
  static bool dark = false;
  static AppPalette palette = AppPalette.presets.first;

  static Color get primary => dark ? palette.primaryLight : palette.primary;
  static Color get primaryLight => palette.primaryLight;
  static Color get primaryDark => palette.primaryDark;
  static Color get secondary => palette.secondary;
  static Color get secondaryLight => palette.secondaryLight;
  static Color get accent => palette.accent;

  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF97316);
  static const Color error = Color(0xFFEF4444);

  // Neutral Backgrounds
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardBorderLight = Color(0xFFE2E8F0);

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardBorderDark = Color(0xFF334155);

  // Typography Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Azkar Calm Gradient
  static const List<Color> azkarCardGradient = [
    Color(0xFF0F766E),
    Color(0xFF115E59),
  ];
}
