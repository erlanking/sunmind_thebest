class TelemetryPoint {
  final String deviceId;
  final double lux;
  final bool motion;
  final int brightness;
  final double batteryVoltage;
  final int batteryPercent;
  final bool manualMode;
  final DateTime createdAt;

  const TelemetryPoint({
    required this.deviceId,
    required this.lux,
    required this.motion,
    required this.brightness,
    required this.batteryVoltage,
    required this.batteryPercent,
    required this.manualMode,
    required this.createdAt,
  });

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) {
    return TelemetryPoint(
      deviceId: json['deviceId'] as String? ?? '',
      lux: (json['lux'] as num?)?.toDouble() ?? 0,
      motion: json['motion'] as bool? ?? false,
      brightness: (json['brightness'] as num?)?.toInt() ?? 0,
      batteryVoltage: (json['batteryVoltage'] as num?)?.toDouble() ?? 0,
      batteryPercent: (json['batteryPercent'] as num?)?.toInt() ?? 0,
      manualMode: json['manualMode'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
