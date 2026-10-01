import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The app's mesh-gradient background with soft glowing orbs.
///
/// The orbs used to drift forever (three endless animations under every screen), which kept the
/// GPU redrawing at the display's refresh rate the whole time the app was open. They now sit where
/// the drift started; each is cached in its own RepaintBoundary, so it is drawn once.
class AnimatedBackground extends StatelessWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Static Mesh Background
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.meshGradient,
          ),
        ),

        // 2. Orbs
        // Orb 1: Top Left - Blue
        Positioned(
          top: -100,
          left: -100,
          child: RepaintBoundary(
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.govBlue.withValues(alpha: 0.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.govBlue.withValues(alpha: 0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Orb 2: Bottom Right - Green
        Positioned(
          bottom: -100,
          right: -100,
          child: RepaintBoundary(
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.govGreen.withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.govGreen.withValues(alpha: 0.15),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
        ),

        // Orb 3: Center/Top - Gold/Warning
        Positioned(
          top: 100,
          right: 50,
          child: RepaintBoundary(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.govGold.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.govGold.withValues(alpha: 0.05),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
        ),

        // 3. Child Content (Glass layer on top)
        // We ensure the child renders above the background
        child,
      ],
    );
  }
}
