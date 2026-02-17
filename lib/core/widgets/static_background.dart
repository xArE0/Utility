import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A static version of AnimatedBackground without animations for better performance.
/// Keeps the same visual theme with gradient mesh background and decorative orbs.
class StaticBackground extends StatelessWidget {
  final Widget child;

  const StaticBackground({super.key, required this.child});

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

        // 2. Static Orbs (simple colored circles, no heavy blur)
        // Orb 1: Top Left - Blue
        Positioned(
          top: -75,
          left: -75,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.govBlue.withOpacity(0.12),
            ),
          ),
        ),

        // Orb 2: Bottom Right - Green
        Positioned(
          bottom: -120,
          right: -120,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.govGreen.withOpacity(0.08),
            ),
          ),
        ),
        
        // Orb 3: Center/Top - Gold/Warning
        Positioned(
          top: 120,
          right: 30,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.govGold.withOpacity(0.04),
            ),
          ),
        ),

        // 3. Child Content
        child,
      ],
    );
  }
}
