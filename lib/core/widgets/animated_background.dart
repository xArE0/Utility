import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The app's backdrop: warm onyx with a soft champagne glow from the top and a faint sage one at
/// the bottom. Plain gradients, no blur or animation, so it is drawn once and costs nothing after.
///
/// (Kept under its old name; it animated once.)
class AnimatedBackground extends StatelessWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.meshGradient),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.6, -1.1),
                    radius: 1.1,
                    colors: [Color(0x26C8A96A), Color(0x00C8A96A)],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(1.0, 1.2),
                      radius: 0.9,
                      colors: [Color(0x148FA98C), Color(0x008FA98C)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
