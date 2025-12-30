import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/palette.dart';

/// Custom refresh indicator with beautiful purple animation
class CustomRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color color;

  const CustomRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color = kPurple,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: color,
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      strokeWidth: 3,
      displacement: 60,
      // Custom builder for the refresh indicator
      child: child,
    );
  }
}

/// Animated refresh header that shows during pull-to-refresh
class AnimatedRefreshHeader extends StatefulWidget {
  final double pullDistance;
  final Color color;

  const AnimatedRefreshHeader({
    super.key,
    required this.pullDistance,
    this.color = kPurple,
  });

  @override
  State<AnimatedRefreshHeader> createState() => _AnimatedRefreshHeaderState();
}

class _AnimatedRefreshHeaderState extends State<AnimatedRefreshHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (widget.pullDistance / 100).clamp(0.0, 1.0);

    return SizedBox(
      height: 80,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: CustomPaint(
                size: Size(40 * progress, 40 * progress),
                painter: _RefreshPainter(
                  color: widget.color,
                  progress: progress,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RefreshPainter extends CustomPainter {
  final Color color;
  final double progress;

  _RefreshPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer circle
    final outerPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, outerPaint);

    // Draw progress arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );

    // Draw center dot
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.2, dotPaint);
  }

  @override
  bool shouldRepaint(_RefreshPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
