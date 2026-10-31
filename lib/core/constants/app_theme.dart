import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/appearance_provider.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme => build(Brightness.light, null);
  static ThemeData get darkTheme => build(Brightness.dark, null);

  static TextTheme _fontTheme(AppFont font, TextTheme base) {
    switch (font) {
      case AppFont.tajawal:
        return GoogleFonts.tajawalTextTheme(base);
      case AppFont.almarai:
        return GoogleFonts.almaraiTextTheme(base);
      case AppFont.naskh:
        return GoogleFonts.notoNaskhArabicTextTheme(base);
      case AppFont.cairo:
        return GoogleFonts.cairoTextTheme(base);
    }
  }

  /// Builds the app theme from the student's choices ([ap] null = defaults).
  static ThemeData build(Brightness brightness, AppearanceProvider? ap) {
    final isDark = brightness == Brightness.dark;
    final palette = ap?.palette ?? AppColors.palette;
    final style = ap?.style ?? UiStyle.modern;
    final amoled = isDark && (ap?.amoled ?? false);

    final primary = isDark ? palette.primaryLight : palette.primary;
    final bg = isDark ? (amoled ? Colors.black : AppColors.backgroundDark) : AppColors.backgroundLight;
    final surface = isDark ? (amoled ? const Color(0xFF0B0B0B) : AppColors.surfaceDark) : AppColors.surfaceLight;
    final border = isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    // Shape language of each interface style.
    final cardRadius = switch (style) { UiStyle.modern => 16.0, UiStyle.flat => 8.0, UiStyle.soft => 24.0 };
    final controlRadius = switch (style) { UiStyle.modern => 12.0, UiStyle.flat => 6.0, UiStyle.soft => 20.0 };
    final cardElevation = style == UiStyle.soft ? 2.0 : 0.0;
    final cardSide = style == UiStyle.modern ? BorderSide(color: border, width: 1) : BorderSide.none;

    final baseText = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final fonts = _fontTheme(ap?.font ?? AppFont.cairo, baseText);
    final textTheme = fonts.copyWith(
      displayLarge: fonts.displayLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
      titleLarge: fonts.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      titleMedium: fonts.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: fonts.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.normal, color: textPrimary),
      bodyMedium: fonts.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.normal, color: textSecondary),
    );

    final scheme = isDark
        ? ColorScheme.dark(
            primary: primary,
            secondary: palette.secondaryLight,
            surface: surface,
            error: AppColors.error,
            onPrimary: Colors.white,
            onSecondary: Colors.black,
            onSurface: textPrimary,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: primary,
            secondary: palette.secondary,
            surface: surface,
            error: AppColors.error,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: textPrimary,
            onError: Colors.white,
          );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      visualDensity: (ap?.compact ?? false) ? VisualDensity.compact : VisualDensity.standard,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: cardElevation,
        shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius), side: cardSide),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: BorderSide(color: primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(controlRadius), borderSide: const BorderSide(color: AppColors.error)),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(style == UiStyle.flat ? 12 : 24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(style == UiStyle.flat ? 12 : 24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(controlRadius + 2)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(style == UiStyle.flat ? 8 : 20)),
        side: style == UiStyle.modern ? BorderSide(color: border) : BorderSide.none,
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(style == UiStyle.flat ? 10 : 18)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? primary.withOpacity(0.35) : null),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? surface : Colors.white,
        indicatorColor: primary.withOpacity(isDark ? 0.2 : 0.12),
        elevation: 4,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary);
          }
          return TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary);
        }),
      ),
    );
  }
}
