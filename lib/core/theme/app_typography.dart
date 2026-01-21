import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static const String fontFamily = 'Inter';

  // Base TextStyles
  static const TextStyle _baseInter = TextStyle(
    fontFamily: fontFamily,
    color: AppColors.slate50,
  );

  // Type Scale
  static TextStyle displayLarge = _baseInter.copyWith(
    fontSize: 57,
    fontWeight: FontWeight.w800, // ExtraBold
    height: 1.1,
    letterSpacing: -0.25,
  );

  static TextStyle displayMedium = _baseInter.copyWith(
    fontSize: 45,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );

  static TextStyle displaySmall = _baseInter.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w700, // Bold
    height: 1.2,
  );

  static TextStyle headlineLarge = _baseInter.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static TextStyle headlineMedium = _baseInter.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w600, // SemiBold
    height: 1.3,
  );

  static TextStyle headlineSmall = _baseInter.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static TextStyle titleLarge = _baseInter.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w500, // Medium
    height: 1.4,
  );

  static TextStyle titleMedium = _baseInter.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.15,
  );

  static TextStyle titleSmall = _baseInter.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.1,
  );

  static TextStyle bodyLarge = _baseInter.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    height: 1.5,
    letterSpacing: 0.5,
  );

  static TextStyle bodyMedium = _baseInter.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.25,
  );

  static TextStyle bodySmall = _baseInter.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.4,
  );
  
  static TextStyle labelLarge = _baseInter.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600, // SemiBold
    height: 1.4,
    letterSpacing: 0.1,
  );

  // Micro Text
  static TextStyle micro = _baseInter.copyWith(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );
  
  // Effects
  static TextStyle glowEffect(Color color) {
    return _baseInter.copyWith(
      shadows: [
        Shadow(
          blurRadius: 10.0,
          color: color,
          offset: const Offset(0, 0),
        ),
      ],
    );
  }
}
