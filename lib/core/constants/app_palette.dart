import 'package:flutter/material.dart';

/// Muted, coordinated palettes inspired by calm native mobile interfaces.
class AppPalette {
  final String id;
  final String name;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color secondary;
  final Color secondaryLight;
  final Color accent;

  const AppPalette({
    required this.id,
    required this.name,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.secondaryLight,
    required this.accent,
  });

  static const List<AppPalette> presets = [
    AppPalette(
      id: 'royal',
      name: 'أخضر سيج هادئ',
      primary: Color(0xFF52796F),
      primaryLight: Color(0xFF84A98C),
      primaryDark: Color(0xFF354F52),
      secondary: Color(0xFF6B9080),
      secondaryLight: Color(0xFFA4C3B2),
      accent: Color(0xFFD6BFA8),
    ),
    AppPalette(
      id: 'forest',
      name: 'أخضر طبيعي',
      primary: Color(0xFF426B5A),
      primaryLight: Color(0xFF83A68E),
      primaryDark: Color(0xFF2D4B40),
      secondary: Color(0xFF789B83),
      secondaryLight: Color(0xFFB2C9B7),
      accent: Color(0xFFD5C6A1),
    ),
    AppPalette(
      id: 'violet',
      name: 'لافندر هادئ',
      primary: Color(0xFF716783),
      primaryLight: Color(0xFFA99DBB),
      primaryDark: Color(0xFF51485F),
      secondary: Color(0xFF958AA6),
      secondaryLight: Color(0xFFC9C1D3),
      accent: Color(0xFFD8C8B8),
    ),
    AppPalette(
      id: 'sunset',
      name: 'طيني دافئ',
      primary: Color(0xFF9A6652),
      primaryLight: Color(0xFFC18D75),
      primaryDark: Color(0xFF704737),
      secondary: Color(0xFFB78369),
      secondaryLight: Color(0xFFD8B6A3),
      accent: Color(0xFFE0C9A6),
    ),
    AppPalette(
      id: 'rose',
      name: 'وردي مطفأ',
      primary: Color(0xFF9B6877),
      primaryLight: Color(0xFFC18F9D),
      primaryDark: Color(0xFF704957),
      secondary: Color(0xFFB88794),
      secondaryLight: Color(0xFFD8B9C1),
      accent: Color(0xFFE0CDBB),
    ),
    AppPalette(
      id: 'ocean',
      name: 'أزرق ضبابي',
      primary: Color(0xFF52758A),
      primaryLight: Color(0xFF8EADBD),
      primaryDark: Color(0xFF354F60),
      secondary: Color(0xFF7597A8),
      secondaryLight: Color(0xFFB5C9D2),
      accent: Color(0xFFD7C9B5),
    ),
    AppPalette(
      id: 'slate',
      name: 'رمادي أنيق',
      primary: Color(0xFF59636E),
      primaryLight: Color(0xFF9AA5AF),
      primaryDark: Color(0xFF3B444D),
      secondary: Color(0xFF7D8791),
      secondaryLight: Color(0xFFC1C8CE),
      accent: Color(0xFFD8CDBB),
    ),
  ];

  static AppPalette byId(String? id) =>
      presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
}
