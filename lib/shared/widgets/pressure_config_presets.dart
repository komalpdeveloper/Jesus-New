import 'pressure_detector.dart';

/// Preset configurations for different haptic sensitivity preferences
/// Use these presets or create custom configurations for fine-tuning
class PressureConfigPresets {
  /// Default balanced configuration
  /// Good for most users and devices
  static const PressureSensitivityConfig standard = PressureSensitivityConfig();

  /// More sensitive - responds to lighter touches
  /// Good for users who prefer gentle interactions
  static const PressureSensitivityConfig sensitive = PressureSensitivityConfig(
    minArea: 150.0,
    maxArea: 2000.0,
    sensitivityMultiplier: 1.3,
    pressureNodes: 12,
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

  /// Less sensitive - requires firmer touches
  /// Good for users who prefer more deliberate interactions
  static const PressureSensitivityConfig firm = PressureSensitivityConfig(
    minArea: 250.0,
    maxArea: 3000.0,
    sensitivityMultiplier: 0.8,
    pressureNodes: 10,
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

  /// Ultra-smooth with maximum nodes
  /// Best for devices with high-precision touch sensors
  static const PressureSensitivityConfig ultraSmooth = PressureSensitivityConfig(
    minArea: 180.0,
    maxArea: 2400.0,
    sensitivityMultiplier: 1.1,
    pressureNodes: 20,
    thresholds: {
      PressureLevel.veryLight: 0.0,
      PressureLevel.light: 0.14,
      PressureLevel.mediumLight: 0.28,
      PressureLevel.medium: 0.43,
      PressureLevel.mediumHeavy: 0.58,
      PressureLevel.heavy: 0.73,
      PressureLevel.veryHeavy: 0.88,
    },
  );

  /// Aggressive response - quick level changes
  /// Good for expressive haptic patterns
  static const PressureSensitivityConfig aggressive = PressureSensitivityConfig(
    minArea: 120.0,
    maxArea: 1800.0,
    sensitivityMultiplier: 1.5,
    pressureNodes: 8,
    thresholds: {
      PressureLevel.veryLight: 0.0,
      PressureLevel.light: 0.10,
      PressureLevel.mediumLight: 0.22,
      PressureLevel.medium: 0.35,
      PressureLevel.mediumHeavy: 0.50,
      PressureLevel.heavy: 0.65,
      PressureLevel.veryHeavy: 0.80,
    },
  );

  /// Custom configuration builder for advanced fine-tuning
  /// 
  /// Example usage:
  /// ```dart
  /// final customConfig = PressureConfigPresets.custom(
  ///   minArea: 200,
  ///   maxArea: 2500,
  ///   sensitivity: 1.2,
  ///   nodes: 15,
  ///   veryLightThreshold: 0.0,
  ///   lightThreshold: 0.15,
  ///   mediumLightThreshold: 0.30,
  ///   mediumThreshold: 0.45,
  ///   mediumHeavyThreshold: 0.60,
  ///   heavyThreshold: 0.75,
  ///   veryHeavyThreshold: 0.90,
  /// );
  /// ```
  static PressureSensitivityConfig custom({
    double minArea = 200.0,
    double maxArea = 2500.0,
    double sensitivity = 1.0,
    int nodes = 10,
    double veryLightThreshold = 0.0,
    double lightThreshold = 0.15,
    double mediumLightThreshold = 0.30,
    double mediumThreshold = 0.45,
    double mediumHeavyThreshold = 0.60,
    double heavyThreshold = 0.75,
    double veryHeavyThreshold = 0.90,
  }) {
    return PressureSensitivityConfig(
      minArea: minArea,
      maxArea: maxArea,
      sensitivityMultiplier: sensitivity,
      pressureNodes: nodes,
      thresholds: {
        PressureLevel.veryLight: veryLightThreshold,
        PressureLevel.light: lightThreshold,
        PressureLevel.mediumLight: mediumLightThreshold,
        PressureLevel.medium: mediumThreshold,
        PressureLevel.mediumHeavy: mediumHeavyThreshold,
        PressureLevel.heavy: heavyThreshold,
        PressureLevel.veryHeavy: veryHeavyThreshold,
      },
    );
  }
}

/// Extension to get human-readable names for pressure levels
extension PressureLevelExtension on PressureLevel {
  String get displayName {
    switch (this) {
      case PressureLevel.veryLight:
        return 'Very Light';
      case PressureLevel.light:
        return 'Light';
      case PressureLevel.mediumLight:
        return 'Medium-Light';
      case PressureLevel.medium:
        return 'Medium';
      case PressureLevel.mediumHeavy:
        return 'Medium-Heavy';
      case PressureLevel.heavy:
        return 'Heavy';
      case PressureLevel.veryHeavy:
        return 'Very Heavy';
    }
  }

  /// Get approximate pressure percentage range
  String get pressureRange {
    switch (this) {
      case PressureLevel.veryLight:
        return '0-15%';
      case PressureLevel.light:
        return '15-30%';
      case PressureLevel.mediumLight:
        return '30-45%';
      case PressureLevel.medium:
        return '45-60%';
      case PressureLevel.mediumHeavy:
        return '60-75%';
      case PressureLevel.heavy:
        return '75-90%';
      case PressureLevel.veryHeavy:
        return '90-100%';
    }
  }
}
