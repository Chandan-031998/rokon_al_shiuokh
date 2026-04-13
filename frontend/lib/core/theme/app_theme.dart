import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        secondary: AppColors.accentGold,
        onSecondary: AppColors.primaryDark,
        error: Color(0xFFB53A2D),
        onError: AppColors.white,
        surface: AppColors.surface,
        onSurface: AppColors.headingText,
      ),
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        color: AppColors.headingText,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        height: 1.02,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        color: AppColors.headingText,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.06,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        color: AppColors.headingText,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
        height: 1.1,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        color: AppColors.headingText,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        color: AppColors.headingText,
        fontWeight: FontWeight.w700,
        height: 1.18,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        color: AppColors.headingText,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        color: AppColors.bodyText,
        height: 1.65,
        letterSpacing: 0.15,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: AppColors.bodyText,
        height: 1.6,
        letterSpacing: 0.12,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        color: AppColors.bodyText,
        height: 1.55,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        color: AppColors.headingText,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.45,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        color: AppColors.bodyText,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        color: AppColors.secondary,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base.colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: textTheme,
      dividerColor: AppColors.border,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.headingText,
        centerTitle: false,
        titleSpacing: 0,
        titleTextStyle: textTheme.titleLarge,
        toolbarTextStyle: textTheme.titleMedium,
        iconTheme: const IconThemeData(color: AppColors.primaryDark),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Color(0x1A2B1A12),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        labelStyle: textTheme.labelLarge?.copyWith(color: AppColors.bodyText),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.bodyText.withValues(alpha: 0.72),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.white,
          shadowColor: const Color(0x332B1A12),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentGold,
          foregroundColor: AppColors.primaryDark,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceRaised,
        side: const BorderSide(color: AppColors.border),
        selectedColor: AppColors.accentLightGold,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.96),
        indicatorColor: AppColors.accentLightGold.withValues(alpha: 0.72),
        height: 80,
        shadowColor: const Color(0x1A2B1A12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.bodyText,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.bodyText,
          );
        }),
      ),
    );
  }
}
