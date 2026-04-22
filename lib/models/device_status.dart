class DeviceStatus {
  final String deviceId;
  final double lux;
  final bool motion;
  final int brightness;
  final double batteryVoltage;
  final int batteryPercent;
  final bool manualMode;
  final DateTime? lastSeen;

  const DeviceStatus({
    required this.deviceId,
    required this.lux,
    required this.motion,
    required this.brightness,
    required this.batteryVoltage,
    required this.batteryPercent,
    required this.manualMode,
    required this.lastSeen,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      deviceId: json['deviceId'] as String? ?? '',
      lux: (json['lux'] as num?)?.toDouble() ?? 0,
      motion: json['motion'] as bool? ?? false,
      brightness: (json['brightness'] as num?)?.toInt() ?? 0,
      batteryVoltage: (json['batteryVoltage'] as num?)?.toDouble() ?? 0,
      batteryPercent: (json['batteryPercent'] as num?)?.toInt() ?? 0,
      manualMode: json['manualMode'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String)
          : null,
    );
  }
}
