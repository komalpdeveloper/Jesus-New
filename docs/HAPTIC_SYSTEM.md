# Haptic System Documentation

## Overview

The haptic system provides pressure-sensitive touch detection and recording for user chat interactions. It supports 7 granular pressure levels for smooth, natural sensations.

## Pressure Levels

The system now supports 7 distinct pressure levels (previously 3):

| Level | Range | Description |
|-------|-------|-------------|
| Very Light | 0-15% | Barely touching the screen |
| Light | 15-30% | Gentle touch |
| Medium-Light | 30-45% | Light press |
| Medium | 45-60% | Normal press |
| Medium-Heavy | 60-75% | Firm press |
| Heavy | 75-90% | Strong press |
| Very Heavy | 90-100% | Maximum pressure |

## Architecture

### Core Components

1. **PressureDetector** (`lib/shared/widgets/pressure_detector.dart`)
   - Detects touch pressure using 3D Touch (touch area)
   - Configurable sensitivity and thresholds
   - Smooth interpolation using pressure nodes
   - Haptic feedback for each level

2. **PressureSensitivityConfig** 
   - Configurable pressure detection parameters
   - Customizable thresholds for each level
   - Adjustable sensitivity multiplier
   - Pressure nodes for smooth transitions

3. **HapticRecorderWidget** (`lib/features/user_chat/widgets/haptic_recorder_widget.dart`)
   - Records haptic patterns with pressure and timing
   - Visual feedback with gradient colors per level
   - Auto-start/stop recording

4. **HapticPattern** (`lib/features/user_chat/models/haptic_pattern_model.dart`)
   - Stores recorded touch events
   - Includes pressure, area, and timestamp data

## Configuration Presets

Use `PressureConfigPresets` for different sensitivity profiles:

```dart
// Standard (default)
PressureDetector(
  config: PressureConfigPresets.standard,
  child: myWidget,
)

// More sensitive
PressureDetector(
  config: PressureConfigPresets.sensitive,
  child: myWidget,
)

// Less sensitive
PressureDetector(
  config: PressureConfigPresets.firm,
  child: myWidget,
)

// Ultra-smooth (20 nodes)
PressureDetector(
  config: PressureConfigPresets.ultraSmooth,
  child: myWidget,
)

// Aggressive response
PressureDetector(
  config: PressureConfigPresets.aggressive,
  child: myWidget,
)
```

## Custom Configuration

Create custom configurations for fine-tuning:

```dart
final customConfig = PressureConfigPresets.custom(
  minArea: 200,              // Min touch area (px²)
  maxArea: 2500,             // Max touch area (px²)
  sensitivity: 1.2,          // Sensitivity multiplier
  nodes: 15,                 // Pressure interpolation nodes
  veryLightThreshold: 0.0,
  lightThreshold: 0.15,
  mediumLightThreshold: 0.30,
  mediumThreshold: 0.45,
  mediumHeavyThreshold: 0.60,
  heavyThreshold: 0.75,
  veryHeavyThreshold: 0.90,
);

PressureDetector(
  config: customConfig,
  child: myWidget,
)
```

## Parameters Explained

### Touch Area Ranges
- **minArea**: Minimum touch area in square pixels (default: 200)
  - Smaller values = more sensitive to light touches
  - Typical light tap: ~200-500 px²

- **maxArea**: Maximum touch area in square pixels (default: 2500)
  - Larger values = can detect harder presses
  - Typical hard press: ~1200-2500 px²

### Sensitivity Multiplier
- **sensitivityMultiplier**: Adjusts overall sensitivity (default: 1.0)
  - < 1.0: Less sensitive (requires firmer press)
  - > 1.0: More sensitive (responds to lighter touch)
  - Range: 0.5 - 2.0 recommended

### Pressure Nodes
- **pressureNodes**: Number of interpolation points (default: 10)
  - Higher values = smoother transitions between levels
  - Lower values = more distinct level changes
  - Range: 5-20 recommended
  - Uses cubic easing for natural feel

### Thresholds
- **thresholds**: Map of pressure levels to normalized values (0.0-1.0)
  - Defines when each pressure level activates
  - Must be in ascending order
  - Default spacing: ~15% between levels

## Haptic Feedback

Each pressure level triggers distinct haptic feedback:

| Level | Haptic Pattern |
|-------|----------------|
| Very Light | None |
| Light | Single light impact |
| Medium-Light | Double light impact (30ms apart) |
| Medium | Single medium impact |
| Medium-Heavy | Double medium impact (40ms apart) |
| Heavy | Double heavy impact (40ms apart) |
| Very Heavy | Triple heavy impact (35ms, 70ms apart) |

## Future Enhancements

The architecture is prepared for:

1. **More Pressure Levels**
   - Easy to add more enum values
   - Update thresholds map
   - Add haptic patterns

2. **Dynamic Sensitivity**
   - User preference settings
   - Per-device calibration
   - Adaptive learning

3. **Advanced Interpolation**
   - Different easing functions
   - Velocity-based adjustments
   - Multi-finger detection

4. **Haptic Pattern Library**
   - Pre-recorded patterns
   - Pattern sharing
   - Pattern effects (echo, fade, etc.)

## Usage Example

```dart
import 'package:your_app/shared/widgets/pressure_detector.dart';
import 'package:your_app/shared/widgets/pressure_config_presets.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PressureDetector(
      config: PressureConfigPresets.sensitive,
      onPressureChanged: (level) {
        print('Pressure level: ${level.displayName}');
        print('Range: ${level.pressureRange}');
      },
      onPressureUpdate: (pressure) {
        print('Raw pressure: ${(pressure * 100).toStringAsFixed(1)}%');
      },
      child: Container(
        width: 200,
        height: 200,
        color: Colors.blue,
        child: Center(child: Text('Press Me')),
      ),
    );
  }
}
```

## Debugging

Enable pressure detection logs:
- Touch area, pressure values, and level changes are logged to console
- Look for `[3D Touch]` prefix in logs
- Shows area-based vs size-based vs duration-based detection

## Performance

- Minimal overhead: ~0.1ms per touch event
- Smooth interpolation: O(1) complexity
- No memory leaks: Proper cleanup on dispose
- Efficient haptic triggering: Only once per level

## Testing

Test different pressure levels:
1. Very light: Barely touch screen
2. Light: Gentle tap
3. Medium-Light: Light press
4. Medium: Normal press
5. Medium-Heavy: Firm press
6. Heavy: Strong press
7. Very Heavy: Maximum force

Observe:
- Visual feedback (gradient colors)
- Haptic feedback intensity
- Pressure percentage display
- Smooth transitions between levels
