import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmind_thebest/core/api/mqtt_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';
import 'package:sunmind_thebest/core/services/notification_service.dart';
import 'package:sunmind_thebest/core/services/session_storage_service.dart';

class SessionCleanupService {
  static const String zoneMetaKey = 'zone_meta_v1';
  static const String deviceMetaKey = 'device_meta_v1';
  static const String deviceZoneAssignmentsKey = 'device_zone_assignments_v1';
  static const String hiddenZonesKey = 'hidden_zones_v1';
  static const String hiddenDevicesKey = 'hidden_devices_v1';
  static const String analyticsCacheKey = 'analytics_cache_v1';
  static const String selectedDeviceKey = 'selected_device_id';
  static const String selectedZoneKey = 'selected_zone_id';

  static Future<Map<String, Map<String, dynamic>>> loadZoneMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(
      prefs,
      zoneMetaKey,
      migrateLegacy: true,
    );
    if (scopedKey == null) return {};

    final raw = prefs.getString(scopedKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveZoneMeta(
    Map<String, Map<String, dynamic>> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(prefs, zoneMetaKey);
    if (scopedKey == null) return;
    await prefs.setString(scopedKey, jsonEncode(value));
  }

  static Future<Map<String, Map<String, dynamic>>> loadDeviceMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(
      prefs,
      deviceMetaKey,
      migrateLegacy: true,
    );
    if (scopedKey == null) return {};

    final raw = prefs.getString(scopedKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveDeviceMeta(
    Map<String, Map<String, dynamic>> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(prefs, deviceMetaKey);
    if (scopedKey == null) return;
    await prefs.setString(scopedKey, jsonEncode(value));
  }

  static Future<Map<String, String>> loadDeviceZoneAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(
      prefs,
      deviceZoneAssignmentsKey,
      migrateLegacy: true,
    );
    if (scopedKey == null) return {};

    final raw = prefs.getString(scopedKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveDeviceZoneAssignments(
    Map<String, String> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(prefs, deviceZoneAssignmentsKey);
    if (scopedKey == null) return;
    await prefs.setString(scopedKey, jsonEncode(value));
  }

  static Future<Set<String>> loadHiddenZones() async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(
      prefs,
      hiddenZonesKey,
      migrateLegacy: true,
    );
    if (scopedKey == null) return <String>{};
    return (prefs.getStringList(scopedKey) ?? const <String>[]).toSet();
  }

  static Future<void> saveHiddenZones(Set<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(prefs, hiddenZonesKey);
    if (scopedKey == null) return;
    await prefs.setStringList(scopedKey, value.toList());
  }

  static Future<Set<String>> loadHiddenDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(
      prefs,
      hiddenDevicesKey,
      migrateLegacy: true,
    );
    if (scopedKey == null) return <String>{};
    return (prefs.getStringList(scopedKey) ?? const <String>[]).toSet();
  }

  static Future<void> saveHiddenDevices(Set<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _resolveScopedKey(prefs, hiddenDevicesKey);
    if (scopedKey == null) return;
    await prefs.setStringList(scopedKey, value.toList());
  }

  static Future<void> clearSessionData({
    NotificationProvider? notificationProvider,
    MqttService? mqttService,
  }) async {
    final activeUserId = await SessionStorageService.getActiveUserId();

    await mqttService?.disconnect();

    if (notificationProvider != null) {
      await notificationProvider.clearAll();
    } else {
      await NotificationService.clearAll(userId: activeUserId);
    }

    await _clearScopedKey(zoneMetaKey, userId: activeUserId);
    await _clearScopedKey(deviceMetaKey, userId: activeUserId);
    await _clearScopedKey(deviceZoneAssignmentsKey, userId: activeUserId);
    await _clearScopedKey(hiddenZonesKey, userId: activeUserId);
    await _clearScopedKey(hiddenDevicesKey, userId: activeUserId);
    await _clearScopedKey(analyticsCacheKey, userId: activeUserId);
    await _clearScopedKey(selectedDeviceKey, userId: activeUserId);
    await _clearScopedKey(selectedZoneKey, userId: activeUserId);

    await _clearLegacyKeys();
    await SessionStorageService.clearSessionMetadata();
  }

  static Future<String?> _resolveScopedKey(
    SharedPreferences prefs,
    String baseKey, {
    bool migrateLegacy = false,
  }) async {
    final userId = await SessionStorageService.getActiveUserId();
    if (userId == null) return null;

    final scopedKey = SessionStorageService.scopedKey(baseKey, userId);
    if (!migrateLegacy ||
        prefs.containsKey(scopedKey) ||
        !prefs.containsKey(baseKey)) {
      return scopedKey;
    }

    final legacyValue = prefs.get(baseKey);
    if (legacyValue is String && legacyValue.isNotEmpty) {
      await prefs.setString(scopedKey, legacyValue);
    } else if (legacyValue is List) {
      final normalized = legacyValue.map((item) => item.toString()).toList();
      await prefs.setStringList(scopedKey, normalized);
    }

    await prefs.remove(baseKey);
    return scopedKey;
  }

  static Future<void> _clearScopedKey(String baseKey, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId =
        userId ?? await SessionStorageService.getActiveUserId();
    if (currentUserId != null) {
      await prefs.remove(
        SessionStorageService.scopedKey(baseKey, currentUserId),
      );
    }
  }

  static Future<void> _clearLegacyKeys() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(zoneMetaKey);
    await prefs.remove(deviceMetaKey);
    await prefs.remove(deviceZoneAssignmentsKey);
    await prefs.remove(hiddenZonesKey);
    await prefs.remove(hiddenDevicesKey);
    await prefs.remove(analyticsCacheKey);
    await prefs.remove(selectedDeviceKey);
    await prefs.remove(selectedZoneKey);
    await prefs.remove(NotificationService.legacyStorageKey);
  }
}
