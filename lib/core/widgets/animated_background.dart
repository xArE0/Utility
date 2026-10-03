import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The app's backdrop: deep navy with a gold glow from the top and a sapphire one at the
/// bottom. Plain gradients, no blur or animation, so it is drawn once and costs nothing after.
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
                    colors: [Color(0x2EFFC24D), Color(0x00FFC24D)],
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(1.0, 1.2),
                      radius: 0.9,
                      colors: [Color(0x334F9DFF), Color(0x004F9DFF)],
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
