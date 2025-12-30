import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/pressure_detector.dart';
import '../../../core/theme/palette.dart';
import '../models/haptic_pattern_model.dart';

/// Widget for recording haptic patterns in chat
class HapticRecorderWidget extends StatefulWidget {
  final Function(HapticPattern) onPatternRecorded;
  final VoidCallback onCancel;

  const HapticRecorderWidget({
    super.key,
    required this.onPatternRecorded,
    required this.onCancel,
  });

  @override
  State<HapticRecorderWidget> createState() => _HapticRecorderWidgetState();
}

class _HapticRecorderWidgetState extends State<HapticRecorderWidget> {
  final List<HapticTouchEvent> _recordedEvents = [];
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _autoStopTimer;
  double _currentPressure = 0.0;
  PressureLevel _currentLevel = PressureLevel.light;
  DateTime _lastHapticTime = DateTime.now();

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    super.dispose();
  }

  void _stopRecording() {
    if (_recordedEvents.isEmpty) {
      widget.onCancel();
      return;
    }

    setState(() {
      _isRecording = false;
    });
    _autoStopTimer?.cancel();

    final durationMs = _recordedEvents.isNotEmpty 
        ? _recordedEvents.last.timestampMs 
        : 0;

    final pattern = HapticPattern(
      events: _recordedEvents,
      durationMs: durationMs,
    );

    widget.onPatternRecorded(pattern);
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

  void _recordHaptic(double pressure, double area) {
    // Auto-start recording on first touch
    if (!_isRecording && pressure > 0) {
      setState(() {
        _recordedEvents.clear();
        _isRecording = true;
        _recordingStartTime = DateTime.now();
      });
    }

    if (!_isRecording) return;

    final timestampMs = DateTime.now().difference(_recordingStartTime!).inMilliseconds;
    _recordedEvents.add(HapticTouchEvent(
      pressure: pressure,
      area: area,
      timestampMs: timestampMs,
    ));

    // Trigger haptic feedback based on pressure
    _triggerHapticForPressure(pressure);

    // Auto-stop after 5 seconds of no input
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(const Duration(seconds: 5), _stopRecording);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: kDeepBlack,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onCancel,
                ),
                Text(
                  'Record Haptic',
                  style: GoogleFonts.lora(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Text(
                  _isRecording ? 'Recording...' : 'Touch the area to start',
                  style: GoogleFonts.lora(
                    fontSize: 18,
                    color: _isRecording ? Colors.red : Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                if (_isRecording)
                  Text(
                    'Pressure: ${(_currentPressure * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.lora(
                      fontSize: 16,
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Touch area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: PressureDetector(
                onPressureChanged: (level) {
                  setState(() {
                    _currentLevel = level;
                  });
                },
                onPressureUpdate: (pressure) {
                  setState(() {
                    _currentPressure = pressure;
                  });

                  // Feedback during recording (throttled)
                  if (DateTime.now().difference(_lastHapticTime).inMilliseconds > 100) {
                     _triggerHapticForPressure(pressure);
                     _lastHapticTime = DateTime.now();
                  }

                  // Always call _recordHaptic - it will auto-start recording on first touch
                  if (pressure > 0) {
                    // Calculate approximate area from pressure
                    final area = 200 + (pressure * 2300); // 200-2500 px²
                    _recordHaptic(pressure, area);
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getGradientColors(),
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _getBorderColor(),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getBorderColor().withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/user_chat/echo.png',
                          width: 160,
                          // height: 80,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isRecording ? 'Recording...' : 'Touch to Start',
                          style: GoogleFonts.lora(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isRecording
                              ? 'Press with different intensities'
                              : 'Touch here to begin recording',
                          style: GoogleFonts.lora(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_isRecording) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _recordedEvents.isNotEmpty ? _stopRecording : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Send'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: widget.onCancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ] else ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors() {
    switch (_currentLevel) {
      case PressureLevel.veryLight:
        return [kRoyalBlue.withValues(alpha: 0.15), kRoyalBlue.withValues(alpha: 0.05)];
      case PressureLevel.light:
        return [kRoyalBlue.withValues(alpha: 0.3), kRoyalBlue.withValues(alpha: 0.15)];
      case PressureLevel.mediumLight:
        return [kRoyalBlue.withValues(alpha: 0.5), kPurple.withValues(alpha: 0.25)];
      case PressureLevel.medium:
        return [kPurple.withValues(alpha: 0.6), kPurple.withValues(alpha: 0.35)];
      case PressureLevel.mediumHeavy:
        return [kPurple.withValues(alpha: 0.75), kGold.withValues(alpha: 0.45)];
      case PressureLevel.heavy:
        return [kGold.withValues(alpha: 0.85), kRed.withValues(alpha: 0.6)];
      case PressureLevel.veryHeavy:
        return [kRed.withValues(alpha: 0.95), kGold.withValues(alpha: 0.75)];
    }
  }

  Color _getBorderColor() {
    switch (_currentLevel) {
      case PressureLevel.veryLight:
        return kRoyalBlue.withValues(alpha: 0.4);
      case PressureLevel.light:
        return kRoyalBlue;
      case PressureLevel.mediumLight:
        return kRoyalBlue.withValues(alpha: 0.8);
      case PressureLevel.medium:
        return kPurple;
      case PressureLevel.mediumHeavy:
        return kPurple.withValues(alpha: 0.9);
      case PressureLevel.heavy:
        return kGold;
      case PressureLevel.veryHeavy:
        return kRed;
    }
  }
}
