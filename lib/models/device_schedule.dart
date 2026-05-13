class DeviceSchedule {
  final String deviceId;
  final int onHour;
  final int onMinute;
  final int offHour;
  final int offMinute;

  const DeviceSchedule({
    required this.deviceId,
    required this.onHour,
    required this.onMinute,
    required this.offHour,
    required this.offMinute,
  });

  factory DeviceSchedule.fromJson(Map<String, dynamic> json) {
    return DeviceSchedule(
      deviceId: json['deviceId'] as String? ?? '',
      onHour: (json['onHour'] as num?)?.toInt() ?? 0,
      onMinute: (json['onMinute'] as num?)?.toInt() ?? 0,
      offHour: (json['offHour'] as num?)?.toInt() ?? 0,
      offMinute: (json['offMinute'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toBody() {
    return {
      'onHour': onHour,
      'onMinute': onMinute,
      'offHour': offHour,
      'offMinute': offMinute,
    };
  }
}
