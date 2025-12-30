import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;

class FlameRewardOverlay extends StatefulWidget {
  const FlameRewardOverlay({super.key, required this.onFinished, this.rings});
  final VoidCallback onFinished;
  final int? rings;

  /// Trigger the flame reward animation overlay with optional rings count
  static void show(BuildContext context, {int? rings}) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => FlameRewardOverlay(
        onFinished: () {
          overlayEntry.remove();
        },
        rings: rings,
      ),
    );
    overlayState.insert(overlayEntry);
  }

  @override
  State<FlameRewardOverlay> createState() => _FlameRewardOverlayState();
}

class _FlameRewardOverlayState extends State<FlameRewardOverlay>
    with SingleTickerProviderStateMixin {
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    // Animation: 1.5s total duration
    // "appear in the center, float up slowly (1.5s), and fade out majestically"
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Float up
    _slideAnim =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -2.5), // Move up "slowly" but noticeably
        ).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeInOutSine, // Majestic float
          ),
        );

    // Fade out at end
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _initResources();
  }

  Future<void> _initResources() async {
    try {
      // Load sound
      try {
        await _audioPlayer.play(ap.AssetSource('reward/audios/sfx_flame.mp3'));
      } catch (e) {
        debugPrint('FlameRewardOverlay: audio error: $e');
      }

      if (mounted) {
        setState(() => _initialized = true);
        // Start animation after resources are ready
        await _animController.forward();
        widget.onFinished();
      }
    } catch (e) {
      debugPrint('Error in FlameRewardOverlay: $e');
      if (mounted) widget.onFinished();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    return Positioned(
      // Center the 100x100 widget (plus text height adjustment)
      top: MediaQuery.of(context).size.height / 2 - 60,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 100, // Size: Large (80px–100px)
                      height: 100,
                      child: Image.asset(
                        'assets/reward/images/ring_flame.webp',
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (widget.rings != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '+${widget.rings} Rings',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD700), // Gold
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          shadows: [
                            BoxShadow(
                              color: Colors.black,
                              blurRadius: 12,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: Colors.orangeAccent,
                              blurRadius: 20,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
