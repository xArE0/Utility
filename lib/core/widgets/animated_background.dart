import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

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

        // 2. Animated Orbs
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
                color: AppColors.govBlue.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.govBlue.withOpacity(0.2),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .move(
            duration: 5.seconds,
            begin: const Offset(0, 0),
            end: const Offset(50, 50),
            curve: Curves.easeInOut,
          )
          .scale(
             duration: 7.seconds,
             begin: const Offset(1,1),
             end: const Offset(1.2, 1.2),
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
                color: AppColors.govGreen.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.govGreen.withOpacity(0.15),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .move(
            duration: 6.seconds,
            begin: const Offset(0, 0),
            end: const Offset(-40, -40),
            curve: Curves.easeInOut,
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
                color: AppColors.govGold.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.govGold.withOpacity(0.05),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .move(
            duration: 8.seconds,
            begin: const Offset(0, 0),
            end: const Offset(-30, 60),
            curve: Curves.easeInOut,
          ),
        ),

        // 3. Child Content (Glass layer on top)
        // We ensure the child renders above the background
        child,
      ],
    );
  }
}
