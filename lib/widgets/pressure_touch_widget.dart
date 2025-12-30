import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A widget that simulates 3D Touch by measuring touch surface area (event.size)
/// to calculate pressure, not duration.
class PressureTouchWidget extends StatefulWidget {
  /// Builder function that provides the current pressure value (0.0 to 1.0)
  final Widget Function(BuildContext context, double pressure) builder;

  /// Minimum touch size (light tap) - default 8.0
  final double minSize;

  /// Maximum touch size (firm press) - default 25.0
  final double maxSize;

  /// Pressure threshold (0.0-1.0) to trigger light haptic feedback
  final double lightHapticThreshold;

  /// Pressure threshold (0.0-1.0) to trigger medium haptic feedback
  final double mediumHapticThreshold;

  /// Pressure threshold (0.0-1.0) to trigger heavy haptic feedback
  final double heavyHapticThreshold;

  /// Callback when pressure changes
  final ValueChanged<double>? onPressureChanged;

  /// Callback when touch starts
  final VoidCallback? onPressStart;

  /// Callback when touch ends
  final VoidCallback? onPressEnd;

  const PressureTouchWidget({
    Key? key,
    required this.builder,
    this.minSize = 8.0,
    this.maxSize = 25.0,
    this.lightHapticThreshold = 0.3,
    this.mediumHapticThreshold = 0.5,
    this.heavyHapticThreshold = 0.7,
    this.onPressureChanged,
    this.onPressStart,
    this.onPressEnd,
  }) : super(key: key);

  @override
  State<PressureTouchWidget> createState() => _PressureTouchWidgetState();
}

class _PressureTouchWidgetState extends State<PressureTouchWidget> {
  double _pressure = 0.0;
  bool _lightHapticTriggered = false;
  bool _mediumHapticTriggered = false;
  bool _heavyHapticTriggered = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerEvent,
      onPointerMove: _handlePointerEvent,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerUp,
      child: widget.builder(context, _pressure),
    );
  }

  void _handlePointerEvent(PointerEvent event) {
    // Read the touch surface area size
    final size = event.size;

    // Map size to pressure (0.0 to 1.0)
    final pressure = _calculatePressure(size);

    // Update state if pressure changed
    if (_pressure != pressure) {
      setState(() {
        _pressure = pressure;
      });

      // Notify callback
      widget.onPressureChanged?.call(_pressure);

      // Trigger haptics based on thresholds
      _triggerHaptics(_pressure);
    }

    // Call onPressStart on first touch
    if (event is PointerDownEvent) {
      widget.onPressStart?.call();
    }
  }

  void _handlePointerUp(PointerEvent event) {
    // Reset pressure and haptic flags
    setState(() {
      _pressure = 0.0;
      _lightHapticTriggered = false;
      _mediumHapticTriggered = false;
      _heavyHapticTriggered = false;
    });

    widget.onPressEnd?.call();
  }

  double _calculatePressure(double size) {
    // Clamp size between min and max
    final clampedSize = size.clamp(widget.minSize, widget.maxSize);

    // Map to 0.0 - 1.0 range
    final pressure =
        (clampedSize - widget.minSize) / (widget.maxSize - widget.minSize);

    return pressure.clamp(0.0, 1.0);
  }

  void _triggerHaptics(double pressure) {
    // Trigger light haptic when crossing threshold
    if (pressure >= widget.lightHapticThreshold && !_lightHapticTriggered) {
      HapticFeedback.lightImpact();
      _lightHapticTriggered = true;
    }

    // Trigger medium haptic when crossing threshold
    if (pressure >= widget.mediumHapticThreshold && !_mediumHapticTriggered) {
      HapticFeedback.mediumImpact();
      _mediumHapticTriggered = true;
    }

    // Trigger heavy haptic when crossing threshold
    if (pressure >= widget.heavyHapticThreshold && !_heavyHapticTriggered) {
      HapticFeedback.heavyImpact();
      _heavyHapticTriggered = true;
    }
  }
}
