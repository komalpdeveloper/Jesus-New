import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clientapp/shared/widgets/pressure_detector.dart';
import 'package:clientapp/core/theme/palette.dart';

class HapticEvent {
  final double pressure;
  final Duration timestamp;

  HapticEvent(this.pressure, this.timestamp);
}

/// Demo screen to showcase pressure-sensitive touch detection
class PressureDemoScreen extends StatefulWidget {
  const PressureDemoScreen({super.key});

  @override
  State<PressureDemoScreen> createState() => _PressureDemoScreenState();
}

class _PressureDemoScreenState extends State<PressureDemoScreen> {
  PressureLevel _currentLevel = PressureLevel.veryLight;
  double _currentPressure = 0.0;
  String _statusMessage = 'Touch the area below';
  
  // Haptic recording
  final List<HapticEvent> _recordedHaptics = [];
  bool _isRecording = false;
  bool _isPlaying = false;
  DateTime? _recordingStartTime;
  Timer? _autoStopTimer;

  @override
  void dispose() {
    _autoStopTimer?.cancel();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _recordedHaptics.clear();
      _isRecording = true;
      _recordingStartTime = null;
      _statusMessage = 'Recording haptics...';
    });
    _autoStopTimer?.cancel();
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _recordingStartTime = null;
      _statusMessage = 'Recording stopped';
    });
    _autoStopTimer?.cancel();
  }

  void _recordHaptic(double pressure) {
    if (!_isRecording) return;

    _recordingStartTime ??= DateTime.now();

    final timestamp = DateTime.now().difference(_recordingStartTime!);
    _recordedHaptics.add(HapticEvent(pressure, timestamp));

    // Auto-stop after 10 seconds of no input
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(const Duration(seconds: 10), _stopRecording);
  }

  Future<void> _playHaptics() async {
    if (_recordedHaptics.isEmpty || _isPlaying) return;

    setState(() {
      _isPlaying = true;
      _statusMessage = 'Playing haptics...';
    });

    for (int i = 0; i < _recordedHaptics.length; i++) {
      final event = _recordedHaptics[i];

      // Wait for correct timing
      if (i > 0) {
        final previousEvent = _recordedHaptics[i - 1];
        final delay = event.timestamp - previousEvent.timestamp;
        await Future.delayed(delay);
      }

      // Trigger haptic based on pressure
      _triggerHapticForPressure(event.pressure);
    }

    setState(() {
      _isPlaying = false;
      _statusMessage = 'Playback finished';
    });
  }

  void _triggerHapticForPressure(double pressure) {
    if (pressure < 0.3) {
      // Very light - single light impact
      HapticFeedback.lightImpact();
    } else if (pressure < 0.5) {
      // Light-medium - double light impact
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 50), () {
        HapticFeedback.lightImpact();
      });
    } else if (pressure < 0.7) {
      // Medium - medium + light combo
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 50), () {
        HapticFeedback.lightImpact();
      });
    } else if (pressure < 0.85) {
      // Heavy - double medium impact
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 50), () {
        HapticFeedback.mediumImpact();
      });
    } else {
      // Very heavy - triple heavy impact
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 40), () {
        HapticFeedback.heavyImpact();
      });
      Future.delayed(const Duration(milliseconds: 80), () {
        HapticFeedback.heavyImpact();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBlack,
      appBar: AppBar(
        title: const Text('Pressure Detection Demo'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Recording controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRecording ? null : _startRecording,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isRecording ? _stopRecording : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                  ElevatedButton.icon(
                    onPressed: (!_isRecording && _recordedHaptics.isNotEmpty && !_isPlaying)
                        ? _playHaptics
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Feel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: _recordedHaptics.isNotEmpty
                        ? () {
                            setState(() {
                              _recordedHaptics.clear();
                              _statusMessage = 'Pattern cleared';
                            });
                          }
                        : null,
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
            
            // Status display
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pressure: ${_currentPressure.toStringAsFixed(2)} (${(_currentPressure * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPressureIndicator(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Interactive pressure detection area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: PressureDetector(
                  onPressureChanged: (level) {
                    setState(() {
                      _currentLevel = level;
                      _statusMessage = _getLevelMessage(level);
                    });
                  },
                  onPressureUpdate: (pressure) {
                    setState(() {
                      _currentPressure = pressure;
                    });
                    
                    // Record haptic if recording
                    if (_isRecording && pressure > 0) {
                      _recordHaptic(pressure);
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
                          Icon(
                            _getLevelIcon(),
                            size: 80,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getLevelText(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getLevelDescription(),
                            style: const TextStyle(
                              fontSize: 16,
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

            // Instructions
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kRoyalBlue.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kRoyalBlue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRecording
                          ? '🔴 Recording haptic pattern...'
                          : _recordedHaptics.isNotEmpty
                              ? '✅ Pattern recorded (${_recordedHaptics.length} haptics)'
                              : '💡 How to use:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isRecording ? Colors.red : kGold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRecording
                          ? 'Touch the area with different pressures'
                          : _recordedHaptics.isNotEmpty
                              ? 'Tap "Feel" to replay the haptic pattern'
                              : '1. Tap "Record"\n2. Touch with different pressures\n3. Tap "Feel" to replay haptics',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPressureIndicator() {
    return Container(
      height: 20,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRoyalBlue),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: _currentPressure.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green,
                    Colors.yellow,
                    Colors.orange,
                    Colors.red,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
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

  IconData _getLevelIcon() {
    switch (_currentLevel) {
      case PressureLevel.veryLight:
        return Icons.touch_app_outlined;
      case PressureLevel.light:
        return Icons.touch_app_outlined;
      case PressureLevel.mediumLight:
        return Icons.touch_app;
      case PressureLevel.medium:
        return Icons.touch_app;
      case PressureLevel.mediumHeavy:
        return Icons.pan_tool_outlined;
      case PressureLevel.heavy:
        return Icons.pan_tool;
      case PressureLevel.veryHeavy:
        return Icons.pan_tool;
    }
  }

  String _getLevelText() {
    switch (_currentLevel) {
      case PressureLevel.veryLight:
        return 'VERY LIGHT';
      case PressureLevel.light:
        return 'LIGHT';
      case PressureLevel.mediumLight:
        return 'MEDIUM-LIGHT';
      case PressureLevel.medium:
        return 'MEDIUM';
      case PressureLevel.mediumHeavy:
        return 'MEDIUM-HEAVY';
      case PressureLevel.heavy:
        return 'HEAVY';
      case PressureLevel.veryHeavy:
        return 'VERY HEAVY';
    }
  }

  String _getLevelDescription() {
    switch (_currentLevel) {
      case PressureLevel.veryLight:
        return 'Barely touching';
      case PressureLevel.light:
        return 'Gentle touch detected';
      case PressureLevel.mediumLight:
        return 'Light press detected\n(Light haptic feedback)';
      case PressureLevel.medium:
        return 'Firm press detected\n(Medium haptic feedback)';
      case PressureLevel.mediumHeavy:
        return 'Strong press detected\n(Strong haptic feedback)';
      case PressureLevel.heavy:
        return 'Very strong press detected\n(Heavy haptic feedback)';
      case PressureLevel.veryHeavy:
        return 'Maximum pressure detected\n(Maximum haptic feedback)';
    }
  }

  String _getLevelMessage(PressureLevel level) {
    switch (level) {
      case PressureLevel.veryLight:
        return 'Very Light Touch';
      case PressureLevel.light:
        return 'Light Touch';
      case PressureLevel.mediumLight:
        return 'Medium-Light Press 📳';
      case PressureLevel.medium:
        return 'Medium Press! 📳';
      case PressureLevel.mediumHeavy:
        return 'Medium-Heavy Press! 💥';
      case PressureLevel.heavy:
        return 'Heavy Press! 💥';
      case PressureLevel.veryHeavy:
        return 'Very Heavy Press! 💥💥';
    }
  }
}
