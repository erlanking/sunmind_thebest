class TelemetryPoint {
  final String deviceId;
  final double lux;
  final bool motion;
  final int brightness;
  final double batteryVoltage;
  final int batteryPercent;
  final double temperature;
  final double humidity;
  final bool manualMode;
  final String powerSource;
  final DateTime createdAt;

  const TelemetryPoint({
    required this.deviceId,
    required this.lux,
    required this.motion,
    required this.brightness,
    required this.batteryVoltage,
    required this.batteryPercent,
    required this.temperature,
    required this.humidity,
    required this.manualMode,
    required this.powerSource,
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
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0,
      manualMode: json['manualMode'] as bool? ?? false,
      powerSource: json['powerSource'] as String? ?? 'battery',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
