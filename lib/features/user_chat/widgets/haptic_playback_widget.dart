import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/palette.dart';
import '../models/haptic_pattern_model.dart';

/// Widget for playing back haptic patterns in message bubbles
class HapticPlaybackWidget extends StatefulWidget {
  final HapticPattern pattern;
  final bool isMe;

  const HapticPlaybackWidget({
    super.key,
    required this.pattern,
    required this.isMe,
  });

  @override
  State<HapticPlaybackWidget> createState() => _HapticPlaybackWidgetState();
}

class _HapticPlaybackWidgetState extends State<HapticPlaybackWidget> {
  bool _isPlaying = false;
  double _playbackProgress = 0.0;

  Future<void> _playHaptics() async {
    if (widget.pattern.events.isEmpty || _isPlaying) return;

    setState(() {
      _isPlaying = true;
      _playbackProgress = 0.0;
    });

    HapticFeedback.lightImpact(); // Start feedback

    for (int i = 0; i < widget.pattern.events.length; i++) {
      final event = widget.pattern.events[i];

      // Wait for correct timing
      if (i > 0) {
        final previousEvent = widget.pattern.events[i - 1];
        final delayMs = event.timestampMs - previousEvent.timestampMs;
        await Future.delayed(Duration(milliseconds: delayMs));
      }

      // Update progress
      if (mounted) {
        setState(() {
          _playbackProgress = event.timestampMs / widget.pattern.durationMs;
        });
      }

      // Trigger haptic based on pressure
      _triggerHapticForPressure(event.pressure);
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playbackProgress = 0.0;
      });
    }

    HapticFeedback.lightImpact(); // End feedback
  }

  void _triggerHapticForPressure(double pressure) {
    // Map pressure (0.0 - 1.0) to 100 intensity levels
    // Gentle (0-33) -> Focused (34-66) -> Hard (67-100)
    
    if (pressure <= 0.01) return;

    if (pressure < 0.33) {
      // Gentle: Subtle feedback
      HapticFeedback.selectionClick();
    } else if (pressure < 0.66) {
      // Focused: Clear, crisp feedback
      HapticFeedback.lightImpact();
      if (pressure > 0.5) {
        // Add slight resonance for upper focused range
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) HapticFeedback.selectionClick();
        });
      }
    } else {
      // Hard: Strong, intense feedback
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 30), () {
        if (mounted) HapticFeedback.heavyImpact();
      });
      
      // Extra intensity for max pressure
      if (pressure > 0.9) {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (mounted) HapticFeedback.heavyImpact();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _playHaptics,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isMe
                ? [kPurple.withValues(alpha: 0.8), kRoyalBlue.withValues(alpha: 0.6)]
                : [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.1)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isMe ? kPurple : Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isPlaying ? Icons.vibration : Icons.fingerprint,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPlaying ? 'Playing...' : 'Haptic Pattern',
                        style: GoogleFonts.lora(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPlaying
                            ? 'Feel the vibration'
                            : 'Tap to feel',
                        style: GoogleFonts.lora(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isPlaying)
                  Icon(
                    Icons.play_circle_outline,
                    color: Colors.white70,
                    size: 28,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _isPlaying ? _playbackProgress : 0.0,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.isMe ? kGold : kPurple,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(widget.pattern.durationMs / 1000).toStringAsFixed(1)}s',
              style: GoogleFonts.lora(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
