import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const String _emergencyAlertsKey = 'emergency_alerts_enabled';
  static const String _pushNotificationsKey = 'push_notifications_enabled';
  static const String _electricityTariffKey = 'electricity_tariff_som';
  static const double defaultTariff = 1.37;

  Future<bool> getEmergencyAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(_emergencyAlertsKey);
    if (value is bool) return value;
    return true;
  }

  Future<void> setEmergencyAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_emergencyAlertsKey, value);
  }

  Future<bool> getPushNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.get(_pushNotificationsKey);
    if (value is bool) return value;
    return true;
  }

  Future<void> setPushNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pushNotificationsKey, value);
  }

  Future<double> getElectricityTariff() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_electricityTariffKey) ?? defaultTariff;
  }

  Future<void> setElectricityTariff(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_electricityTariffKey, value);
  }
}
