import 'package:flutter/material.dart';

class AppColors {
  // Primary "Gov" Colors
  static const Color govGreen = Color(0xFF059669);
  static const Color govBlue = Color(0xFF2563eb);
  static const Color govGold = Color(0xFFd97706);

  // Slate Scale
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate900 = Color(0xFF0F172A);

  // Semantic Colors
  static const Color success = govGreen;
  static const Color warning = govGold;
  static const Color error = Color(0xFFEF4444); // Red-500
  static const Color info = govBlue;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [govBlue, govGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0x1AFFFFFF), Color(0x05FFFFFF)], // Low opacity white
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient meshGradient = LinearGradient(
    colors: [slate900, slate800],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows (Glows)
  static final List<BoxShadow> glowShadow = [
    BoxShadow(
      color: govBlue.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];
}
