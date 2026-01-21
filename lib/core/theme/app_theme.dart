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
        secondary: AppColors.govGold,
        surface: AppColors.slate800,
        error: AppColors.error, 
        // We use slate900 for background mainly
        background: AppColors.slate900,
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
      cardTheme: CardTheme(
        color: AppColors.slate800.withOpacity(0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.slate700.withOpacity(0.5),
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
