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

  /// A quiet, native-mobile visual language: restrained color, soft surfaces,
  /// subtle borders and consistent rounded geometry.
  static ThemeData build(Brightness brightness, AppearanceProvider? ap) {
    final isDark = brightness == Brightness.dark;
    final palette = ap?.palette ?? AppColors.palette;
    final style = ap?.style ?? UiStyle.modern;
    final amoled = isDark && (ap?.amoled ?? false);

    final primary = isDark ? palette.primaryLight : palette.primary;
    final bg = isDark
        ? (amoled ? Colors.black : AppColors.backgroundDark)
        : AppColors.backgroundLight;
    final surface = isDark
        ? (amoled ? const Color(0xFF101214) : AppColors.surfaceDark)
        : AppColors.surfaceLight;
    final border = isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;
    final textPrimary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final cardRadius = switch (style) {
      UiStyle.modern => 20.0,
      UiStyle.flat => 12.0,
      UiStyle.soft => 24.0,
    };
    final controlRadius = switch (style) {
      UiStyle.modern => 14.0,
      UiStyle.flat => 10.0,
      UiStyle.soft => 20.0,
    };
    final cardSide = BorderSide(color: border, width: 0.8);

    final baseText = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final fonts = _fontTheme(ap?.font ?? AppFont.cairo, baseText);
    final textTheme = fonts.copyWith(
      displayLarge: fonts.displayLarge?.copyWith(
        fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      titleLarge: fonts.titleLarge?.copyWith(
        fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      titleMedium: fonts.titleMedium?.copyWith(
        fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      bodyLarge: fonts.bodyLarge?.copyWith(
        fontSize: 15, height: 1.55, color: textPrimary,
      ),
      bodyMedium: fonts.bodyMedium?.copyWith(
        fontSize: 13, height: 1.45, color: textSecondary,
      ),
    );

    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: isDark ? palette.secondaryLight : palette.secondary,
      onSecondary: isDark ? Colors.black : Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: isDark
          ? const Color(0xFF292E32)
          : const Color(0xFFEDEF F1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      primaryColor: primary,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme,
      visualDensity: (ap?.compact ?? false)
          ? VisualDensity.compact
          : VisualDensity.standard,
      textTheme: textTheme,
      dividerColor: border,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary, size: 22),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: style == UiStyle.soft ? 1.5 : 0,
        shadowColor: Colors.black.withOpacity(isDark ? 0.22 : 0.035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: cardSide,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF24292D) : const Color(0xFFEDEF F1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(controlRadius),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withOpacity(0.28)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(controlRadius + 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        side: BorderSide(color: border),
        showCheckmark: false,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: primary,
        textColor: textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? primary : null,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withOpacity(isDark ? 0.22 : 0.11),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primary : textSecondary,
          );
        }),
      ),
    );
  }
}
