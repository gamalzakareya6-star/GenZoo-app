import 'package:flutter/material.dart';

/// A set of brand colors the student can choose in "المظهر والتخصيص".
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
      name: 'أزرق ملكي',
      primary: Color(0xFF1E3A8A),
      primaryLight: Color(0xFF3B82F6),
      primaryDark: Color(0xFF172554),
      secondary: Color(0xFF0D9488),
      secondaryLight: Color(0xFF2DD4BF),
      accent: Color(0xFFF59E0B),
    ),
    AppPalette(
      id: 'forest',
      name: 'أخضر الطبيعة',
      primary: Color(0xFF047857),
      primaryLight: Color(0xFF10B981),
      primaryDark: Color(0xFF064E3B),
      secondary: Color(0xFF0E7490),
      secondaryLight: Color(0xFF22D3EE),
      accent: Color(0xFFF59E0B),
    ),
    AppPalette(
      id: 'violet',
      name: 'بنفسجي',
      primary: Color(0xFF6D28D9),
      primaryLight: Color(0xFFA78BFA),
      primaryDark: Color(0xFF4C1D95),
      secondary: Color(0xFFDB2777),
      secondaryLight: Color(0xFFF472B6),
      accent: Color(0xFFFBBF24),
    ),
    AppPalette(
      id: 'sunset',
      name: 'غروب برتقالي',
      primary: Color(0xFFC2410C),
      primaryLight: Color(0xFFFB923C),
      primaryDark: Color(0xFF7C2D12),
      secondary: Color(0xFFB45309),
      secondaryLight: Color(0xFFFCD34D),
      accent: Color(0xFF0EA5E9),
    ),
    AppPalette(
      id: 'rose',
      name: 'وردي هادئ',
      primary: Color(0xFFBE185D),
      primaryLight: Color(0xFFF472B6),
      primaryDark: Color(0xFF831843),
      secondary: Color(0xFF7C3AED),
      secondaryLight: Color(0xFFC4B5FD),
      accent: Color(0xFFF59E0B),
    ),
    AppPalette(
      id: 'ocean',
      name: 'محيط',
      primary: Color(0xFF0369A1),
      primaryLight: Color(0xFF38BDF8),
      primaryDark: Color(0xFF0C4A6E),
      secondary: Color(0xFF0F766E),
      secondaryLight: Color(0xFF5EEAD4),
      accent: Color(0xFFF97316),
    ),
    AppPalette(
      id: 'slate',
      name: 'رمادي أنيق',
      primary: Color(0xFF334155),
      primaryLight: Color(0xFF94A3B8),
      primaryDark: Color(0xFF0F172A),
      secondary: Color(0xFF64748B),
      secondaryLight: Color(0xFFCBD5E1),
      accent: Color(0xFFEAB308),
    ),
  ];

  static AppPalette byId(String? id) => presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
}
