import 'package:flutter/material.dart';

/// "Sapphire & Gold": deep navy neutrals with a saturated gold accent, plus a set of vivid jewel
/// tones for anything colour-coded (categories, event types, charts). The cool backdrop is what
/// makes the warm gold read bright rather than beige.
///
/// The token names predate this theme (the app started out slate-and-blue) and are kept so the
/// ~600 places that use them didn't need touching: `govBlue` is the primary accent, `govGreen` the
/// secondary, `govGold` the tertiary, and `slate50`…`slate900` the neutral scale, light to dark.
class AppColors {
  // Accents
  static const Color govBlue = Color(0xFFFFC24D); // gold — primary
  static const Color govGreen = Color(0xFF3DD9A0); // emerald — secondary / success
  static const Color govGold = Color(0xFFFF8F4D); // tangerine — tertiary / edit / warning

  /// Text and icons on an accent-coloured fill (buttons, FABs, chips): dark, not white.
  static const Color onAccent = Color(0xFF0B1222);

  // Neutral scale (navy)
  static const Color slate50 = Color(0xFFF5F7FC);
  static const Color slate100 = Color(0xFFE6EBF5);
  static const Color slate200 = Color(0xFFCDD5E6);
  static const Color slate300 = Color(0xFFA9B4CC);
  static const Color slate400 = Color(0xFF8590AC);
  static const Color slate500 = Color(0xFF5A6582);
  static const Color slate600 = Color(0xFF323C58);
  static const Color slate700 = Color(0xFF212A44);
  static const Color slate800 = Color(0xFF141B30);
  static const Color slate900 = Color(0xFF0A0F1F);

  // Jewel tones: vivid colour-coding, tuned to sit on navy.
  static const Color rose = Color(0xFFFF6B8B);
  static const Color sapphire = Color(0xFF4F9DFF);
  static const Color amethyst = Color(0xFFA98BFF);
  static const Color aqua = Color(0xFF38D0F0);
  static const Color teal = Color(0xFF2CC9B5);
  static const Color jade = Color(0xFF3DD9A0);
  static const Color jadeDeep = Color(0xFF0F3D33);
  static const Color amber = Color(0xFFFFB020);
  static const Color coral = Color(0xFFFF7A59);

  // Semantic Colors
  static const Color success = govGreen;
  static const Color warning = amber;
  static const Color error = Color(0xFFFF5A5F);
  static const Color info = sapphire;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [govBlue, govGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0x16E6EEFF), Color(0x06E6EEFF)], // faint cool white
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient meshGradient = LinearGradient(
    colors: [Color(0xFF111A36), slate900],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Shadows (Glows)
  static final List<BoxShadow> glowShadow = [
    BoxShadow(
      color: govBlue.withValues(alpha: 0.25),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];
}
