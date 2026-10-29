import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surfaceLight,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimaryLight,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.cairoTextTheme().copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryLight,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryLight,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryLight,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimaryLight,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondaryLight,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorderLight, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        elevation: 4,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondaryLight,
          );
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primaryLight,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        surface: AppColors.surfaceDark,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: AppColors.textPrimaryDark,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.cairo(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimaryDark,
        ),
        titleLarge: GoogleFonts.cairo(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDark,
        ),
        titleMedium: GoogleFonts.cairo(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimaryDark,
        ),
        bodyLarge: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimaryDark,
        ),
        bodyMedium: GoogleFonts.cairo(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondaryDark,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorderDark, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        hintStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.primaryLight.withOpacity(0.2),
        elevation: 4,
      ),
    );
  }
}
