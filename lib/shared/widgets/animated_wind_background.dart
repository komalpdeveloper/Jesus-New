import 'package:flutter/material.dart';
import 'package:clientapp/core/theme/palette.dart';

/// Subtle animated gradient that flows like wind across the sacred palette.
class AnimatedWindBackground extends StatefulWidget {
  const AnimatedWindBackground({super.key});
  @override
  State<AnimatedWindBackground> createState() => _AnimatedWindBackgroundState();
}

class _AnimatedWindBackgroundState extends State<AnimatedWindBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, __) {
        final t = _ctl.value;
        final c1 = Color.lerp(kRoyalBlue, kPurple, t)!;
        final c2 = Color.lerp(kRed, kGold, t)!;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.9 + t * 0.2, -1.0),
              end: Alignment( 1.0, 0.9 - t * 0.2),
              colors: [c1, c2],
            ),
          ),
        );
      },
    );
  }
}
