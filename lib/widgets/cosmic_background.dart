import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:clientapp/core/theme/palette.dart';

/// A layered cosmic background: subtle stars, drifting nebula, and vignette.
class CosmicBackground extends StatelessWidget {
  final Widget? child;
  final Color accent;
  const CosmicBackground({super.key, this.child, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base deep gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kDeepBlack, kRoyalBlue],
            ),
          ),
        ),
        // Slow moving nebula swirl
        const _NebulaLayer(),
        // Twinkling stars
  _StarsLayer(color: accent.withValues(alpha: 0.5)),
        // Soft vignette
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.0, -0.2),
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.35),
                ],
                stops: const [0.6, 1.0],
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _NebulaLayer extends StatefulWidget {
  const _NebulaLayer();
  @override
  State<_NebulaLayer> createState() => _NebulaLayerState();
}

class _NebulaLayerState extends State<_NebulaLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();
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
        // Use only brand colors: accent, purple, deep black. Avoid gold here to prevent greenish casts.
        final accentSoft = kPurple.withValues(alpha: 0.05 + 0.05 * math.sin(t * math.pi * 2));
        final sweep = [
          accentSoft,
          kDeepBlack,
          kRoyalBlue.withValues(alpha: 0.06),
          kDeepBlack,
          accentSoft,
        ];
        return Container(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              colors: sweep,
              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              center: const Alignment(-0.2, -0.3),
            ),
          ),
        );
      },
    );
  }
}

class _StarsLayer extends StatefulWidget {
  final Color color;
  const _StarsLayer({required this.color});
  @override
  State<_StarsLayer> createState() => _StarsLayerState();
}

class _StarsLayerState extends State<_StarsLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  final math.Random _rng = math.Random(7);
  late final List<Offset> _stars;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _stars = List.generate(80, (i) => Offset(_rng.nextDouble(), _rng.nextDouble()));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) {
          return CustomPaint(
            painter: _StarsPainter(_stars, widget.color, _ctl.value),
            size: MediaQuery.of(context).size,
          );
        },
      ),
    );
  }
}

class _StarsPainter extends CustomPainter {
  final List<Offset> stars;
  final Color color;
  final double t;
  _StarsPainter(this.stars, this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < stars.length; i++) {
      final o = stars[i];
      final dx = o.dx * size.width;
      final dy = o.dy * size.height;
      final twinkle = (math.sin((i * 0.7) + t * math.pi * 2) + 1) / 2;
  paint.color = color.withValues(alpha: 0.15 + twinkle * 0.35);
      canvas.drawCircle(Offset(dx, dy), 0.7 + (twinkle * 1.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) => oldDelegate.t != t || oldDelegate.color != color;
}

/// Adds a subtle reflective sheen sweep over its child.
class Sheen extends StatefulWidget {
  final Widget child;
  final Duration period;
  const Sheen({super.key, required this.child, this.period = const Duration(seconds: 8)});

  @override
  State<Sheen> createState() => _SheenState();
}

class _SheenState extends State<Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: widget.period)..repeat();
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
        return ShaderMask(
          shaderCallback: (rect) {
            final x = rect.width * _ctl.value;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.25),
                Colors.transparent,
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: GradientRotation(0.3),
            ).createShader(Rect.fromLTWH(x - rect.width, 0, rect.width, rect.height));
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}
