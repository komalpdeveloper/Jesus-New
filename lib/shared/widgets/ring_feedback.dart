import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class RingFeedback {
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static void show(BuildContext context) {
    // Play sound
    try {
      _audioPlayer.stop(); // Stop previous if any
      _audioPlayer.play(AssetSource('reward/audios/sfx_mini.m4a'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }

    // Show visual
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final overlayEntry = OverlayEntry(
      builder: (context) => const _RingAnimation(),
    );

    overlay.insert(overlayEntry);

    // Remove after animation
    Future.delayed(const Duration(milliseconds: 800), () {
      overlayEntry.remove();
    });
  }
}

class _RingAnimation extends StatefulWidget {
  const _RingAnimation();

  @override
  State<_RingAnimation> createState() => _RingAnimationState();
}

class _RingAnimationState extends State<_RingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    // Float up
    _position = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -100), // Move up 100 pixels
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Position fixed at bottom-right area, adjusting for keyboard
    return Positioned(
      bottom: bottomInset + 80, // Start just above the input area (approx)
      right: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: _position.value,
            child: Opacity(
              opacity: _opacity.value,
              child: Image.asset(
                'assets/reward/images/ring_gold.webp',
                width: 30,
                height: 30,
              ),
            ),
          );
        },
      ),
    );
  }
}
