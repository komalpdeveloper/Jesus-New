/// Model for storing haptic touch events
class HapticTouchEvent {
  final double pressure;
  final double area; // Touch area in square pixels
  final int timestampMs; // Milliseconds from start of recording

  const HapticTouchEvent({
    required this.pressure,
    required this.area,
    required this.timestampMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'pressure': pressure,
      'area': area,
      'timestampMs': timestampMs,
    };
  }

  static HapticTouchEvent fromJson(Map<String, dynamic> json) {
    return HapticTouchEvent(
      pressure: (json['pressure'] as num?)?.toDouble() ?? 0.0,
      area: (json['area'] as num?)?.toDouble() ?? 0.0,
      timestampMs: json['timestampMs'] as int? ?? 0,
    );
  }
}

/// Model for a complete haptic pattern
class HapticPattern {
  final List<HapticTouchEvent> events;
  final int durationMs; // Total duration of the pattern

  const HapticPattern({
    required this.events,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'events': events.map((e) => e.toJson()).toList(),
      'durationMs': durationMs,
    };
  }

  static HapticPattern fromJson(Map<String, dynamic> json) {
    final eventsList = json['events'] as List?;
    return HapticPattern(
      events: eventsList?.map((e) => HapticTouchEvent.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      durationMs: json['durationMs'] as int? ?? 0,
    );
  }
}
