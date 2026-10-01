import 'package:flutter/material.dart';

/// "Onyx & Champagne": warm near-black neutrals, a champagne-gold accent, and a set of muted jewel
/// tones for anything colour-coded (categories, event types, charts).
///
/// The token names predate this theme (the app started out slate-and-blue) and are kept so the
/// ~600 places that use them didn't need touching: `govBlue` is the primary accent, `govGreen` the
/// secondary, `govGold` the tertiary, and `slate50`…`slate900` the neutral scale, light to dark.
class AppColors {
  // Accents
  static const Color govBlue = Color(0xFFC8A96A); // champagne — primary
  static const Color govGreen = Color(0xFF8FA98C); // sage — secondary / success
  static const Color govGold = Color(0xFFC07A4F); // copper — tertiary / edit / warning

  /// Text and icons on an accent-coloured fill (buttons, FABs, chips): dark, not white.
  static const Color onAccent = Color(0xFF14110D);

  // Neutral scale (warm onyx)
  static const Color slate50 = Color(0xFFFAF7F2);
  static const Color slate100 = Color(0xFFF1ECE3);
  static const Color slate200 = Color(0xFFE3DCCF);
  static const Color slate300 = Color(0xFFC9C1B4);
  static const Color slate400 = Color(0xFF9C9488);
  static const Color slate500 = Color(0xFF6F685E);
  static const Color slate600 = Color(0xFF3E3A34);
  static const Color slate700 = Color(0xFF2A2723);
  static const Color slate800 = Color(0xFF171513);
  static const Color slate900 = Color(0xFF0C0B0A);

  // Jewel tones: muted stand-ins for bright colour-coding, tuned to sit on onyx.
  static const Color rose = Color(0xFFC98490);
  static const Color sapphire = Color(0xFF7D97C2);
  static const Color amethyst = Color(0xFFA08CC0);
  static const Color aqua = Color(0xFF79AFB8);
  static const Color teal = Color(0xFF6FA59B);
  static const Color jade = Color(0xFF7FB09A);
  static const Color jadeDeep = Color(0xFF2F4A3E);
  static const Color amber = Color(0xFFD4A65A);
  static const Color coral = Color(0xFFC9805E);

  // Semantic Colors
  static const Color success = govGreen;
  static const Color warning = amber;
  static const Color error = Color(0xFFD2625A);
  static const Color info = sapphire;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [govBlue, govGold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0x14FFF6E5), Color(0x05FFF6E5)], // faint warm white
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient meshGradient = LinearGradient(
    colors: [Color(0xFF12100E), slate900],
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
