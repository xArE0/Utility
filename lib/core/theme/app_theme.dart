import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.govBlue,
      scaffoldBackgroundColor: AppColors.slate900,

      fontFamily: AppTypography.fontFamily,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: AppColors.govBlue,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.govGreen,
        onSecondary: AppColors.onAccent,
        tertiary: AppColors.govGold,
        surface: AppColors.slate800,
        onSurface: AppColors.slate50,
        surfaceContainerHighest: AppColors.slate700,
        outline: AppColors.slate600,
        error: AppColors.error,
      ),

      // Accent-filled controls carry dark text (champagne is too light for white).
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.govBlue,
        foregroundColor: AppColors.onAccent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.govBlue,
          foregroundColor: AppColors.onAccent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.govBlue,
          foregroundColor: AppColors.onAccent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.govBlue),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.slate800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.slate700),
        ),
        titleTextStyle: AppTypography.titleLarge,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.slate700,
        contentTextStyle: TextStyle(color: AppColors.slate50),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.govBlue,
        selectionColor: AppColors.govBlue.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.govBlue,
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.displaySmall,
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.labelLarge,
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.titleLarge.copyWith(
          color: AppColors.slate50,
        ),
        iconTheme: const IconThemeData(color: AppColors.slate50),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.slate800.withValues(alpha: 0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.slate700.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.slate700,
        thickness: 1,
      ),
    );
  }
}
