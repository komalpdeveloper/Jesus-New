import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ElectricRewardOverlay extends StatefulWidget {
  const ElectricRewardOverlay({super.key, required this.onFinished});
  final VoidCallback onFinished;

  /// Trigger the electric reward animation overlay
  static void show(BuildContext context) {
    final overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => ElectricRewardOverlay(
        onFinished: () {
          overlayEntry.remove();
        },
      ),
    );
    overlayState.insert(overlayEntry);
  }

  @override
  State<ElectricRewardOverlay> createState() => _ElectricRewardOverlayState();
}

class _ElectricRewardOverlayState extends State<ElectricRewardOverlay>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;

  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  bool _initialized = false;
  bool _usingFallback = false;

  @override
  void initState() {
    super.initState();

    // Animation: 1.5s total duration as requested
    // "appear in the center, float up with high energy (1.5s), and fade out"
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Float up
    _slideAnim =
        Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -3.0), // Move up significantly
        ).animate(
          CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutCubic, // Energetic float
          ),
        );

    // Fade out at end
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _initResources();
  }

  Future<void> _initResources() async {
    try {
      // Sound playback removed as per request

      // Try loading visual

      try {
        _videoController = VideoPlayerController.asset(
          'assets/ring/ring_electric.webm',
        );
        await _videoController!.initialize();
        _videoController!.setLooping(true);
        await _videoController!.play();
      } catch (_) {
        // Fallback to GIF if webm missing
        debugPrint('ElectricRewardOverlay: webm missing, using fallback GIF');
        _usingFallback = true;
      }

      if (mounted) {
        setState(() => _initialized = true);
        // Start animation after resources are ready
        await _animController.forward();
        widget.onFinished();
      }
    } catch (e) {
      debugPrint('Error in ElectricRewardOverlay: $e');
      // If everything fails, clean up
      if (mounted) widget.onFinished();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    return Positioned(
      // Center the 100x100 widget
      top: MediaQuery.of(context).size.height / 2 - 50,
      left: MediaQuery.of(context).size.width / 2 - 50,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SizedBox(
                  width: 100, // Size: Large (80px–100px)
                  height: 100,
                  child: _usingFallback
                      ? ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.cyanAccent, // Light Blue tint
                            BlendMode.srcATop,
                          ),
                          child: Image.asset(
                            'assets/ring/ring.gif',
                            fit: BoxFit.contain,
                          ),
                        )
                      : VideoPlayer(_videoController!),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
