import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

class SwipeAnswerPad extends StatefulWidget {
  final void Function(String answer) onAnswer;
  final int optionCount;
  final bool enabled;
  final String? feedbackAnswer;
  final bool? feedbackCorrect;

  const SwipeAnswerPad({
    super.key,
    required this.onAnswer,
    required this.optionCount,
    this.enabled = true,
    this.feedbackAnswer,
    this.feedbackCorrect,
  });

  @override
  State<SwipeAnswerPad> createState() => _SwipeAnswerPadState();
}

class _SwipeAnswerPadState extends State<SwipeAnswerPad>
    with TickerProviderStateMixin {
  String? _activeDirection;
  Offset? _panStartPosition;
  Offset? _panLastPosition;

  late final AnimationController _feedbackController;
  late final Animation<double> _feedbackGlow;

  @override
  void initState() {
    super.initState();
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _feedbackGlow = CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.easeOut,
    );
  }

  @override
  void didUpdateWidget(covariant SwipeAnswerPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedbackAnswer != null &&
        widget.feedbackAnswer != oldWidget.feedbackAnswer) {
      _feedbackController.forward(from: 0.0);
    }
    if (widget.feedbackAnswer == null && oldWidget.feedbackAnswer != null) {
      _feedbackController.reset();
    }
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    
    // Initialize start position on first update
    _panStartPosition ??= details.globalPosition - details.delta;
    _panLastPosition = details.globalPosition;
    
    // Calculate accumulated delta from start
    final accumulatedDelta = _panLastPosition! - _panStartPosition!;
    final dx = accumulatedDelta.dx;
    final dy = accumulatedDelta.dy;
    final distance = accumulatedDelta.distance;

    String? direction;
    if (distance >= 50.0) {
      if (dx.abs() > dy.abs()) {
        direction = dx > 0 ? 'B' : 'D';
      } else if (dy.abs() > dx.abs()) {
        direction = dy < 0 ? 'A' : 'C';
      }
    }

    if (direction != _activeDirection) {
      setState(() => _activeDirection = direction);
    }
  }

   void _onPanEnd(DragEndDetails details) {
     if (!widget.enabled) return;
     
     setState(() => _activeDirection = null);
     
     // Use accumulated delta from start to end
     if (_panStartPosition == null || _panLastPosition == null) {
       _panStartPosition = null;
       _panLastPosition = null;
       return;
     }
     
     final accumulatedDelta = _panLastPosition! - _panStartPosition!;
     final dx = accumulatedDelta.dx;
     final dy = accumulatedDelta.dy;
     final distance = accumulatedDelta.distance;
     
     // Require minimum distance (not velocity) for swipes (deadzone boundary)
     if (distance < 50.0) {
       _panStartPosition = null;
       _panLastPosition = null;
       return;
     }

     String answer;
     if (dy.abs() > dx.abs()) {
       // Vertical dominant
       answer = dy < 0 ? 'A' : 'C'; // up=A, down=C
     } else {
       // Horizontal dominant
       answer = dx > 0 ? 'B' : 'D'; // right=B, left=D
     }
     
     _panStartPosition = null;
     _panLastPosition = null;
     widget.onAnswer(answer);
   }

  void _onPanCancel() {
    setState(() => _activeDirection = null);
    _panStartPosition = null;
    _panLastPosition = null;
  }

  void _onTap() {
    if (!widget.enabled) return;
    if (widget.optionCount >= 5) {
      widget.onAnswer('E');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.enabled ? 1.0 : 0.3,
      duration: const Duration(milliseconds: 250),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: _onPanCancel,
        onTap: _onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              painter: _CompassPainter(),
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Stack(
                  children: [
                    // A — Top center
                    _buildDirectionLabel(
                      answer: 'A',
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: 32),
                      icon: Icons.keyboard_arrow_up_rounded,
                      iconBelow: false,
                    ),
                    // B — Right center
                    _buildDirectionLabel(
                      answer: 'B',
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      icon: Icons.keyboard_arrow_right_rounded,
                      iconBelow: false,
                      horizontal: true,
                      iconAfter: true,
                    ),
                    // C — Bottom center
                    _buildDirectionLabel(
                      answer: 'C',
                      alignment: Alignment.bottomCenter,
                      padding: const EdgeInsets.only(bottom: 32),
                      icon: Icons.keyboard_arrow_down_rounded,
                      iconBelow: true,
                    ),
                    // D — Left center
                    _buildDirectionLabel(
                      answer: 'D',
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      icon: Icons.keyboard_arrow_left_rounded,
                      iconBelow: false,
                      horizontal: true,
                      iconAfter: false,
                    ),
                    // E — Center (only if 5 options)
                    if (widget.optionCount >= 5)
                      _buildCenterLabel(),
                    // Center dot (always shown)
                    if (widget.optionCount < 5)
                      Center(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.slate800.withOpacity(0.5),
                            border: Border.all(
                              color: AppColors.slate600,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDirectionLabel({
    required String answer,
    required Alignment alignment,
    required EdgeInsets padding,
    required IconData icon,
    required bool iconBelow,
    bool horizontal = false,
    bool iconAfter = false,
  }) {
    final isFeedback = widget.feedbackAnswer == answer;
    final isActive = _activeDirection == answer;
    final feedbackColor = isFeedback
        ? (widget.feedbackCorrect == true
            ? AppColors.success
            : AppColors.error)
        : null;

    return AnimatedBuilder(
      animation: _feedbackGlow,
      builder: (context, child) {
        final glowValue = isFeedback ? _feedbackGlow.value : 0.0;
        final scale = isActive ? 1.15 : (1.0 + glowValue * 0.15);
        final labelColor = isFeedback
            ? Color.lerp(AppColors.slate400, feedbackColor, glowValue)!
            : (isActive ? AppColors.slate200 : AppColors.slate400);
        final glowOpacity = glowValue * 0.6;

        return Align(
          alignment: alignment,
          child: Padding(
            padding: padding,
            child: Transform.scale(
              scale: scale,
              child: Container(
                decoration: isFeedback && glowOpacity > 0
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: feedbackColor!.withOpacity(glowOpacity),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      )
                    : null,
                child: horizontal
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: iconAfter
                            ? [
                                _letterWidget(answer, labelColor),
                                const SizedBox(width: 2),
                                Icon(icon, color: labelColor, size: 20),
                              ]
                            : [
                                Icon(icon, color: labelColor, size: 20),
                                const SizedBox(width: 2),
                                _letterWidget(answer, labelColor),
                              ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: iconBelow
                            ? [
                                _letterWidget(answer, labelColor),
                                Icon(icon, color: labelColor, size: 20),
                              ]
                            : [
                                Icon(icon, color: labelColor, size: 20),
                                _letterWidget(answer, labelColor),
                              ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _letterWidget(String letter, Color color) {
    return Text(
      letter,
      style: AppTypography.headlineMedium.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildCenterLabel() {
    final isFeedback = widget.feedbackAnswer == 'E';
    final feedbackColor = isFeedback
        ? (widget.feedbackCorrect == true
            ? AppColors.success
            : AppColors.error)
        : null;

    return AnimatedBuilder(
      animation: _feedbackGlow,
      builder: (context, child) {
        final glowValue = isFeedback ? _feedbackGlow.value : 0.0;
        final labelColor = isFeedback
            ? Color.lerp(AppColors.slate400, feedbackColor, glowValue)!
            : AppColors.slate400;
        final borderColor = isFeedback
            ? Color.lerp(AppColors.slate600, feedbackColor, glowValue)!
            : AppColors.slate600;
        final glowOpacity = glowValue * 0.5;

        return Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.slate800.withOpacity(0.5),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: isFeedback && glowOpacity > 0
                  ? [
                      BoxShadow(
                        color: feedbackColor!.withOpacity(glowOpacity),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'E',
                    style: AppTypography.titleMedium.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'TAP',
                    style: AppTypography.micro.copyWith(
                      color: labelColor.withOpacity(0.6),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// AnimatedBuilder — a convenience wrapper around AnimatedWidget
/// so we can use inline builder with an animation.
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;
  final Widget? child;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, child);
}

/// Custom painter for the subtle compass crosshair lines.
class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Determine line lengths (from center outward, leaving gap near center)
    const innerGap = 56.0;
    final maxHorizontal = size.width / 2 - 60;
    final maxVertical = size.height / 2 - 80;

    // Vertical line — up
    _drawGradientLine(
      canvas,
      center + const Offset(0, -innerGap),
      center + Offset(0, -maxVertical),
      paint,
    );
    // Vertical line — down
    _drawGradientLine(
      canvas,
      center + const Offset(0, innerGap),
      center + Offset(0, maxVertical),
      paint,
    );
    // Horizontal line — right
    _drawGradientLine(
      canvas,
      center + const Offset(innerGap, 0),
      center + Offset(maxHorizontal, 0),
      paint,
    );
    // Horizontal line — left
    _drawGradientLine(
      canvas,
      center + const Offset(-innerGap, 0),
      center + Offset(-maxHorizontal, 0),
      paint,
    );

    // Dotted deadzone circle (radius 50.0)
    final dottedPaint = Paint()
      ..color = AppColors.slate600.withOpacity(0.4)
      ..style = PaintingStyle.fill;
    const double radius = 50.0;
    const int dotCount = 40;
    for (int i = 0; i < dotCount; i++) {
      final double angle = (i * 2 * math.pi) / dotCount;
      final double x = center.dx + radius * math.cos(angle);
      final double y = center.dy + radius * math.sin(angle);
      canvas.drawCircle(Offset(x, y), 1.0, dottedPaint);
    }

    // Center circle
    final circlePaint = Paint()
      ..color = AppColors.slate700.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 26, circlePaint);

    // Small inner dot
    final dotPaint = Paint()
      ..color = AppColors.slate600
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, dotPaint);
  }

  void _drawGradientLine(
      Canvas canvas, Offset start, Offset end, Paint basePaint) {
    final shader = LinearGradient(
      colors: [
        AppColors.slate600.withOpacity(0.6),
        AppColors.slate700.withOpacity(0.1),
      ],
    ).createShader(Rect.fromPoints(start, end));

    final paint = Paint()
      ..shader = shader
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
