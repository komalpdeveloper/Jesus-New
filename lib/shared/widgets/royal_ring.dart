import 'package:flutter/material.dart';

enum RoyalRingBehavior {
  chat, // Quick float up
  meditation, // Majestic slow float up
  electric, // High-energy float up
}

class RoyalRing extends StatelessWidget {
  final Color glowColor;
  final double size;

  const RoyalRing({super.key, required this.glowColor, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.6),
            blurRadius: size * 0.8,
            spreadRadius: size * 0.2,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: 0.4),
            blurRadius: size * 0.4,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
      child: Image.asset(
        'assets/reward/images/ring_gold.webp',
        fit: BoxFit.contain,
      ),
    );
  }

  /// Show the RoyalRing overlay
  static void show(
    BuildContext context, {
    required Color glowColor,
    required double size,
    required RoyalRingBehavior behavior,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _RoyalRingOverlayAnimation(
        glowColor: glowColor,
        size: size,
        behavior: behavior,
        onFinished: () {
          overlayEntry.remove();
        },
      ),
    );

    overlayState.insert(overlayEntry);
  }
}

class _RoyalRingOverlayAnimation extends StatefulWidget {
  final Color glowColor;
  final double size;
  final RoyalRingBehavior behavior;
  final VoidCallback onFinished;

  const _RoyalRingOverlayAnimation({
    required this.glowColor,
    required this.size,
    required this.behavior,
    required this.onFinished,
  });

  @override
  State<_RoyalRingOverlayAnimation> createState() =>
      _RoyalRingOverlayAnimationState();
}

class _RoyalRingOverlayAnimationState extends State<_RoyalRingOverlayAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _configureAnimation();
    _controller.forward().then((_) => widget.onFinished());
  }

  void _configureAnimation() {
    Duration duration;
    Curve slideCurve;
    Offset endOffset;

    switch (widget.behavior) {
      case RoyalRingBehavior.chat:
        // Behavior: Float up quickly.
        duration = const Duration(milliseconds: 800);
        slideCurve = Curves.easeOutBack;
        endOffset = const Offset(0, -3.0); // Quick short float
        break;
      case RoyalRingBehavior.meditation:
        // Behavior: Majestic slow float up.
        duration = const Duration(milliseconds: 2500);
        slideCurve = Curves.easeInOutSine;
        endOffset = const Offset(0, -4.0); // Slow high float
        break;
      case RoyalRingBehavior.electric:
        // Behavior: High-energy float up.
        duration = const Duration(milliseconds: 1200);
        slideCurve = Curves.easeOutCubic;
        endOffset = const Offset(0, -5.0); // Fast high float
        break;
    }

    _controller = AnimationController(vsync: this, duration: duration);

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0),
      end: endOffset,
    ).animate(CurvedAnimation(parent: _controller, curve: slideCurve));

    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Positioning logic
    double? top;
    double? bottom;
    double? left;
    double? right;

    if (widget.behavior == RoyalRingBehavior.chat) {
      // Start from bottom right roughly where the send button is
      bottom = 100;
      right = 20;
    } else {
      // Center of screen
      top = MediaQuery.of(context).size.height / 2 - (widget.size / 2);
      left = MediaQuery.of(context).size.width / 2 - (widget.size / 2);
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: RoyalRing(
                  glowColor: widget.glowColor,
                  size: widget.size,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
