class HomeViewCache {
  final String userName;
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> cards;

  const HomeViewCache({
    required this.userName,
    required this.devices,
    required this.cards,
  });
}

class AnalyticsViewCache {
  final String period;
  final double totalKwh;
  final double avgSavings;
  final int totalMotionCount;
  final double lightOnHours;
  final double? remainingEnergyWh;
  final double? remainingHours;
  final int? latestBatteryPercent;
  final double tariff;
  final double costSom;
  final List<double> consumptionByBucket;
  final List<double> motionByBucket;
  final List<double> batteryByBucket;
  final List<double> acByBucket;
  final List<double> batterySourceByBucket;
  final List<String> bucketLabels;
  final List<Map<String, dynamic>> zoneShares;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> devices;

  const AnalyticsViewCache({
    required this.period,
    required this.totalKwh,
    required this.avgSavings,
    required this.totalMotionCount,
    required this.lightOnHours,
    required this.remainingEnergyWh,
    required this.remainingHours,
    required this.latestBatteryPercent,
    required this.tariff,
    required this.costSom,
    required this.consumptionByBucket,
    required this.motionByBucket,
    required this.batteryByBucket,
    required this.acByBucket,
    required this.batterySourceByBucket,
    required this.bucketLabels,
    required this.zoneShares,
    required this.events,
    required this.devices,
  });
}

class ProfileViewCache {
  final String? name;
  final String? email;
  final double tariff;

  const ProfileViewCache({
    required this.name,
    required this.email,
    required this.tariff,
  });
}

class ViewCacheService {
  ViewCacheService._();

  static HomeViewCache? home;
  static final Map<String, AnalyticsViewCache> analyticsByPeriod =
      <String, AnalyticsViewCache>{};
  static ProfileViewCache? profile;
}
