class AnalyticsSummary {
  final double avgLux;
  final double minLux;
  final double maxLux;
  final int motionCount;
  final int lightOnMinutes;
  final int avgBrightness;
  final int batteryMin;
  final int batteryMax;
  final double energyWh;
  final double energyKwh;
  final double estimatedSavingsPercent;
  final double? remainingEnergyWh;
  final double? remainingHours;

  const AnalyticsSummary({
    required this.avgLux,
    required this.minLux,
    required this.maxLux,
    required this.motionCount,
    required this.lightOnMinutes,
    required this.avgBrightness,
    required this.batteryMin,
    required this.batteryMax,
    required this.energyWh,
    required this.energyKwh,
    required this.estimatedSavingsPercent,
    this.remainingEnergyWh,
    this.remainingHours,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummary(
      avgLux: (json['avgLux'] as num?)?.toDouble() ?? 0,
      minLux: (json['minLux'] as num?)?.toDouble() ?? 0,
      maxLux: (json['maxLux'] as num?)?.toDouble() ?? 0,
      motionCount: (json['motionCount'] as num?)?.toInt() ?? 0,
      lightOnMinutes: (json['lightOnMinutes'] as num?)?.toInt() ?? 0,
      avgBrightness: (json['avgBrightness'] as num?)?.toInt() ?? 0,
      batteryMin: (json['batteryMin'] as num?)?.toInt() ?? 0,
      batteryMax: (json['batteryMax'] as num?)?.toInt() ?? 0,
      energyWh: (json['energyWh'] as num?)?.toDouble() ?? 0,
      energyKwh: (json['energyKwh'] as num?)?.toDouble() ?? 0,
      estimatedSavingsPercent:
          (json['estimatedSavingsPercent'] as num?)?.toDouble() ?? 0,
      remainingEnergyWh: (json['remainingEnergyWh'] as num?)?.toDouble(),
      remainingHours: (json['remainingHours'] as num?)?.toDouble(),
    );
  }
}
