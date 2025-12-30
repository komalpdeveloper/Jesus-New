import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Enum to represent the pressure level of a touch
/// Extended with more granular levels for smoother, natural sensation
enum PressureLevel {
  veryLight,    // 0-15%
  light,        // 15-30%
  mediumLight,  // 30-45%
  medium,       // 45-60%
  mediumHeavy,  // 60-75%
  heavy,        // 75-90%
  veryHeavy,    // 90-100%
}

/// Configuration for pressure sensitivity
/// Allows fine-tuning of pressure detection behavior
class PressureSensitivityConfig {
  /// Minimum touch area in square pixels (default: 200)
  final double minArea;
  
  /// Maximum touch area in square pixels (default: 2500)
  final double maxArea;
  
  /// Pressure thresholds for each level (0.0 to 1.0)
  final Map<PressureLevel, double> thresholds;
  
  /// Number of pressure nodes for interpolation (default: 10)
  /// Higher values = smoother transitions
  final int pressureNodes;
  
  /// Sensitivity multiplier (default: 1.0)
  /// < 1.0 = less sensitive, > 1.0 = more sensitive
  final double sensitivityMultiplier;

  const PressureSensitivityConfig({
    this.minArea = 200.0,
    this.maxArea = 2500.0,
    this.thresholds = const {
      PressureLevel.veryLight: 0.0,
      PressureLevel.light: 0.15,
      PressureLevel.mediumLight: 0.30,
      PressureLevel.medium: 0.45,
      PressureLevel.mediumHeavy: 0.60,
      PressureLevel.heavy: 0.75,
      PressureLevel.veryHeavy: 0.90,
    },
    this.pressureNodes = 10,
    this.sensitivityMultiplier = 1.0,
  });

  /// Create a more sensitive configuration
  factory PressureSensitivityConfig.sensitive() {
    return const PressureSensitivityConfig(
      minArea: 150.0,
      maxArea: 2000.0,
      sensitivityMultiplier: 1.3,
      thresholds: {
        PressureLevel.veryLight: 0.0,
        PressureLevel.light: 0.12,
        PressureLevel.mediumLight: 0.25,
        PressureLevel.medium: 0.40,
        PressureLevel.mediumHeavy: 0.55,
        PressureLevel.heavy: 0.70,
        PressureLevel.veryHeavy: 0.85,
      },
    );
  }

  /// Create a less sensitive configuration
  factory PressureSensitivityConfig.firm() {
    return const PressureSensitivityConfig(
      minArea: 250.0,
      maxArea: 3000.0,
      sensitivityMultiplier: 0.8,
      thresholds: {
        PressureLevel.veryLight: 0.0,
        PressureLevel.light: 0.18,
        PressureLevel.mediumLight: 0.35,
        PressureLevel.medium: 0.50,
        PressureLevel.mediumHeavy: 0.65,
        PressureLevel.heavy: 0.80,
        PressureLevel.veryHeavy: 0.95,
      },
    );
  }
}

/// A widget that detects pressure-sensitive touch using 3D Touch (event.size)
/// Measures touch surface area, NOT duration
class PressureDetector extends StatefulWidget {
  /// The child widget to wrap with pressure detection
  final Widget child;

  /// Callback when pressure level changes
  final ValueChanged<PressureLevel>? onPressureChanged;

  /// Callback with continuous pressure value (0.0 to 1.0)
  final ValueChanged<double>? onPressureUpdate;

  /// Minimum touch size (light tap) - default 5.0
  final double minSize;

  /// Maximum touch size (firm press) - default 20.0
  final double maxSize;

  /// Whether to enable haptic feedback (default: true)
  final bool enableHaptics;

  /// Pressure sensitivity configuration
  final PressureSensitivityConfig config;

  const PressureDetector({
    super.key,
    required this.child,
    this.onPressureChanged,
    this.onPressureUpdate,
    this.minSize = 5.0,
    this.maxSize = 20.0,
    this.enableHaptics = true,
    this.config = const PressureSensitivityConfig(),
  });

  @override
  State<PressureDetector> createState() => _PressureDetectorState();
}

class _PressureDetectorState extends State<PressureDetector> {
  PressureLevel _currentLevel = PressureLevel.veryLight;
  double _currentPressure = 0.0;
  final Map<PressureLevel, bool> _hapticTriggered = {};
  DateTime? _touchStartTime;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: widget.child,
    );
  }

  void _handlePointerDown(PointerEvent event) {
    _isPressed = true;
    _touchStartTime = DateTime.now();
    _updatePressure(event);
  }

  void _handlePointerMove(PointerEvent event) {
    if (_isPressed) {
      _updatePressure(event);
    }
  }

  void _updatePressure(PointerEvent event) {
    if (_touchStartTime == null) return;
    
    // Get touch radius in pixels
    final radiusMajor = event.radiusMajor;
    final radiusMinor = event.radiusMinor;
    final size = event.size;
    final duration = DateTime.now().difference(_touchStartTime!).inMilliseconds;
    
    // Calculate touch area in square pixels (ellipse area = π * a * b)
    double touchArea = 0.0;
    if (radiusMajor > 0 && radiusMinor > 0) {
      touchArea = 3.14159 * radiusMajor * radiusMinor;
    } else if (radiusMajor > 0) {
      // If only major radius available, assume circular
      touchArea = 3.14159 * radiusMajor * radiusMajor;
    }
    
    debugPrint('[3D Touch] radiusMajor: $radiusMajor, radiusMinor: $radiusMinor, area: ${touchArea.toStringAsFixed(1)}px², size: $size, duration: ${duration}ms');

    double calculatedPressure = 0.0;

    // Primary method: Use touch area in pixels
    if (touchArea > 0) {
      calculatedPressure = _calculatePressureFromArea(touchArea);
      debugPrint('[3D Touch] ✓ Area-based pressure: $calculatedPressure (${touchArea.toStringAsFixed(1)}px²)');
    } else if (size > 0) {
      // Fallback 1: Use event.size
      calculatedPressure = _calculatePressure(size);
      debugPrint('[3D Touch] ✓ Size-based pressure: $calculatedPressure (size: $size)');
    } else {
      // Fallback 2: Duration-based
      if (duration < 300) {
        calculatedPressure = 0.2 + (duration / 300) * 0.3;
      } else if (duration < 600) {
        calculatedPressure = 0.5 + ((duration - 300) / 300) * 0.3;
      } else {
        calculatedPressure = 0.8 + ((duration - 600) / 1000) * 0.2;
      }
      calculatedPressure = calculatedPressure.clamp(0.0, 1.0);
      debugPrint('[3D Touch] ⚠️ Duration fallback: $calculatedPressure (${duration}ms)');
    }

    setState(() {
      _currentPressure = calculatedPressure;
    });
    
    widget.onPressureUpdate?.call(_currentPressure);

    final newLevel = _determinePressureLevel(_currentPressure);
    if (newLevel != _currentLevel) {
      debugPrint('[3D Touch] Level: ${_currentLevel.name} -> ${newLevel.name}');
      setState(() {
        _currentLevel = newLevel;
      });
      _triggerHapticFeedback(newLevel);
      widget.onPressureChanged?.call(newLevel);
    }
  }

  void _handlePointerUp(PointerEvent event) {
    _isPressed = false;
    _touchStartTime = null;
    
    setState(() {
      _currentPressure = 0.0;
      _currentLevel = PressureLevel.veryLight;
      _hapticTriggered.clear();
    });
    
    widget.onPressureUpdate?.call(0.0);
  }

  double _calculatePressureFromArea(double area) {
    // Use configurable area ranges for better customization
    final minArea = widget.config.minArea;
    final maxArea = widget.config.maxArea;
    
    final clampedArea = area.clamp(minArea, maxArea);
    var pressure = (clampedArea - minArea) / (maxArea - minArea);
    
    // Apply sensitivity multiplier
    pressure *= widget.config.sensitivityMultiplier;
    
    // Apply smooth interpolation using pressure nodes
    pressure = _smoothPressure(pressure);
    
    return pressure.clamp(0.0, 1.0);
  }

  /// Smooth pressure using configurable nodes for natural feel
  double _smoothPressure(double rawPressure) {
    final nodes = widget.config.pressureNodes;
    final nodeSize = 1.0 / nodes;
    final nodeIndex = (rawPressure / nodeSize).floor();
    final nodeProgress = (rawPressure % nodeSize) / nodeSize;
    
    // Cubic easing for smoother transitions
    final easedProgress = nodeProgress * nodeProgress * (3.0 - 2.0 * nodeProgress);
    
    return ((nodeIndex + easedProgress) * nodeSize).clamp(0.0, 1.0);
  }

  double _calculatePressure(double size) {
    final clampedSize = size.clamp(widget.minSize, widget.maxSize);
    final pressure = (clampedSize - widget.minSize) / (widget.maxSize - widget.minSize);
    return pressure.clamp(0.0, 1.0);
  }

  PressureLevel _determinePressureLevel(double pressure) {
    final thresholds = widget.config.thresholds;
    
    // Check from highest to lowest threshold
    if (pressure >= thresholds[PressureLevel.veryHeavy]!) {
      return PressureLevel.veryHeavy;
    } else if (pressure >= thresholds[PressureLevel.heavy]!) {
      return PressureLevel.heavy;
    } else if (pressure >= thresholds[PressureLevel.mediumHeavy]!) {
      return PressureLevel.mediumHeavy;
    } else if (pressure >= thresholds[PressureLevel.medium]!) {
      return PressureLevel.medium;
    } else if (pressure >= thresholds[PressureLevel.mediumLight]!) {
      return PressureLevel.mediumLight;
    } else if (pressure >= thresholds[PressureLevel.light]!) {
      return PressureLevel.light;
    } else {
      return PressureLevel.veryLight;
    }
  }

  void _triggerHapticFeedback(PressureLevel level) {
    if (!widget.enableHaptics) return;
    if (_hapticTriggered[level] == true) return;

    // Trigger haptic based on pressure level with varying intensities
    switch (level) {
      case PressureLevel.veryLight:
        // No haptic for very light touch
        break;
      
      case PressureLevel.light:
        HapticFeedback.lightImpact();
        _hapticTriggered[level] = true;
        break;
      
      case PressureLevel.mediumLight:
        HapticFeedback.lightImpact();
        Future.delayed(const Duration(milliseconds: 30), () {
          HapticFeedback.lightImpact();
        });
        _hapticTriggered[level] = true;
        break;
      
      case PressureLevel.medium:
        HapticFeedback.mediumImpact();
        _hapticTriggered[level] = true;
        break;
      
      case PressureLevel.mediumHeavy:
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 40), () {
          HapticFeedback.mediumImpact();
        });
        _hapticTriggered[level] = true;
        break;
      
      case PressureLevel.heavy:
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 40), () {
          HapticFeedback.heavyImpact();
        });
        _hapticTriggered[level] = true;
        break;
      
      case PressureLevel.veryHeavy:
        // Triple heavy impact for maximum intensity
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 35), () {
          HapticFeedback.heavyImpact();
        });
        Future.delayed(const Duration(milliseconds: 70), () {
          HapticFeedback.heavyImpact();
        });
        _hapticTriggered[level] = true;
        break;
    }
  }
}
