class DeviceStatus {
  final String deviceId;
  final double lux;
  final bool motion;
  final int brightness;
  final double batteryVoltage;
  final int batteryPercent;
  final double temperature;
  final double humidity;
  final String mode; // "manual" | "auto" | "schedule"
  final String powerSource; // "battery" | "ac"
  final DateTime? lastSeen;

  const DeviceStatus({
    required this.deviceId,
    required this.lux,
    required this.motion,
    required this.brightness,
    required this.batteryVoltage,
    required this.batteryPercent,
    required this.temperature,
    required this.humidity,
    required this.mode,
    required this.powerSource,
    required this.lastSeen,
  });

  bool get manualMode => mode == 'manual';

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    // Поддержка старого bool-поля manualMode и нового строкового mode
    String resolveMode() {
      final m = json['mode'];
      if (m is String && m.isNotEmpty) return m;
      final mm = json['manualMode'] ?? json['manual_mode'];
      if (mm == true) return 'manual';
      if (mm == false) return 'auto';
      return 'manual';
    }

    return DeviceStatus(
      deviceId: json['deviceId'] as String? ?? '',
      lux: (json['lux'] as num?)?.toDouble() ?? 0,
      motion: (json['motion'] ?? json['motion_active']) as bool? ?? false,
      brightness: (json['brightness'] as num?)?.toInt() ?? 0,
      batteryVoltage:
          ((json['batteryVoltage'] ?? json['battery_voltage']) as num?)
              ?.toDouble() ??
          0,
      batteryPercent:
          ((json['batteryPercent'] ?? json['battery_percent']) as num?)
              ?.toInt() ??
          0,
      temperature:
          ((json['temperature'] ?? json['temp']) as num?)?.toDouble() ?? 0,
      humidity: ((json['humidity'] ?? json['humid']) as num?)?.toDouble() ?? 0,
      mode: resolveMode(),
      powerSource: (json['powerSource'] as String?)?.toLowerCase() == 'ac' ? 'ac' : 'battery',
      lastSeen: json['lastSeen'] != null
          ? DateTime.tryParse(json['lastSeen'] as String)
          : null,
    );
  }
}
