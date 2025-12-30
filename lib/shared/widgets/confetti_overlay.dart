import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

/// A reusable confetti overlay widget that can be triggered programmatically
class ConfettiOverlay extends StatefulWidget {
  final Widget child;

  const ConfettiOverlay({
    super.key,
    required this.child,
  });

  @override
  State<ConfettiOverlay> createState() => ConfettiOverlayState();
}

class ConfettiOverlayState extends State<ConfettiOverlay> {
  late ConfettiController _controllerCenter;
  late ConfettiController _controllerLeft;
  late ConfettiController _controllerRight;

  @override
  void initState() {
    super.initState();
    _controllerCenter = ConfettiController(duration: const Duration(seconds: 3));
    _controllerLeft = ConfettiController(duration: const Duration(seconds: 3));
    _controllerRight = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _controllerCenter.dispose();
    _controllerLeft.dispose();
    _controllerRight.dispose();
    super.dispose();
  }

  /// Trigger the confetti animation
  void celebrate() {
    print('🎉 Confetti celebrate() called!');
    _controllerCenter.play();
    _controllerLeft.play();
    _controllerRight.play();
  }

  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);

    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);

    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step),
          halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Confetti layer - positioned to be on top
        IgnorePointer(
          child: Stack(
            children: [
              // Center confetti
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _controllerCenter,
                  blastDirection: pi / 2, // down
                  emissionFrequency: 0.05,
                  numberOfParticles: 20,
                  maxBlastForce: 20,
                  minBlastForce: 10,
                  gravity: 0.3,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Colors.yellow,
                    Colors.red,
                  ],
                  createParticlePath: _drawStar,
                ),
              ),
              // Left confetti
              Align(
                alignment: Alignment.topLeft,
                child: ConfettiWidget(
                  confettiController: _controllerLeft,
                  blastDirection: 0, // right
                  emissionFrequency: 0.05,
                  numberOfParticles: 15,
                  maxBlastForce: 15,
                  minBlastForce: 8,
                  gravity: 0.3,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Colors.yellow,
                    Colors.red,
                  ],
                  createParticlePath: _drawStar,
                ),
              ),
              // Right confetti
              Align(
                alignment: Alignment.topRight,
                child: ConfettiWidget(
                  confettiController: _controllerRight,
                  blastDirection: pi, // left
                  emissionFrequency: 0.05,
                  numberOfParticles: 15,
                  maxBlastForce: 15,
                  minBlastForce: 8,
                  gravity: 0.3,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                    Colors.yellow,
                    Colors.red,
                  ],
                  createParticlePath: _drawStar,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
