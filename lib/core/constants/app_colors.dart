import 'package:flutter/material.dart';

import 'app_palette.dart';

class AppColors {
  static bool dark = false;
  static AppPalette palette = AppPalette.presets.first;

  static Color get primary => dark ? palette.primaryLight : palette.primary;
  static Color get primaryLight => palette.primaryLight;
  static Color get primaryDark => palette.primaryDark;
  static Color get secondary => palette.secondary;
  static Color get secondaryLight => palette.secondaryLight;
  static Color get accent => palette.accent;

  static const Color success = Color(0xFF43856A);
  static const Color warning = Color(0xFFC18A4A);
  static const Color error = Color(0xFFC45D5D);

  // Soft neutral surfaces reduce contrast fatigue without sacrificing clarity.
  static const Color backgroundLight = Color(0xFFF5F6F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardBorderLight = Color(0xFFE7E9EC);

  static const Color backgroundDark = Color(0xFF111315);
  static const Color surfaceDark = Color(0xFF1C2023);
  static const Color cardBorderDark = Color(0xFF30363A);

  static const Color textPrimaryLight = Color(0xFF202528);
  static const Color textSecondaryLight = Color(0xFF747D82);
  static const Color textPrimaryDark = Color(0xFFF1F3F4);
  static const Color textSecondaryDark = Color(0xFFA2AAAE);

  static const List<Color> azkarCardGradient = [
    Color(0xFF52796F),
    Color(0xFF354F52),
  ];
}
