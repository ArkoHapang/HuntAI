import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.dark,
      primary: AppColors.orange,
      secondary: AppColors.blue,
      error: AppColors.red,
      surface: AppColors.card,
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: AppColors.primaryText,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.primaryText,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.primaryText,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.primaryText),
        bodyMedium: TextStyle(color: AppColors.primaryText),
        bodySmall: TextStyle(color: AppColors.secondaryText),
        labelMedium: TextStyle(color: AppColors.secondaryText),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: .16),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondaryCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.orange),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.sidebar,
        indicatorColor: Color(0x33FF851B),
        selectedIconTheme: IconThemeData(color: AppColors.orange),
        unselectedIconTheme: IconThemeData(color: AppColors.secondaryText),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.orange,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.orange,
      brightness: Brightness.light,
      primary: const Color(0xFFC45A00),
      secondary: AppColors.blue,
      error: AppColors.red,
      surface: AppColors.lightSurface,
    );
    return ThemeData(
      colorScheme: scheme,
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.lightBackground,
      dividerColor: AppColors.lightBorder,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: AppColors.lightText,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.lightText,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.lightText,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.lightText),
        bodyMedium: TextStyle(color: AppColors.lightText),
        bodySmall: TextStyle(color: AppColors.lightSecondaryText),
        labelMedium: TextStyle(color: AppColors.lightSecondaryText),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F2F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
