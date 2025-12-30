import 'package:flutter/material.dart';

/// Heaven Glow effect widget for bottom navbar buttons
/// Creates a pulsating ethereal glow effect
class HeavenGlow extends StatefulWidget {
  const HeavenGlow({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.isSelected = false,
  });

  final Widget child;
  final Color color;
  final bool isSelected;

  @override
  State<HeavenGlow> createState() => _HeavenGlowState();
}

class _HeavenGlowState extends State<HeavenGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // High-intensity glow for selected buttons, low-intensity for unselected
    final intensityMultiplier = widget.isSelected ? 1.0 : 0.3;
    
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4 * _glowAnimation.value * intensityMultiplier),
                blurRadius: 20 * _glowAnimation.value * intensityMultiplier,
                spreadRadius: 5 * _glowAnimation.value * intensityMultiplier,
              ),
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3 * _glowAnimation.value * intensityMultiplier),
                blurRadius: 35 * _glowAnimation.value * intensityMultiplier,
                spreadRadius: 8 * _glowAnimation.value * intensityMultiplier,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2 * _glowAnimation.value * intensityMultiplier),
                blurRadius: 50 * _glowAnimation.value * intensityMultiplier,
                spreadRadius: 10 * _glowAnimation.value * intensityMultiplier,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
