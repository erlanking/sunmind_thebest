import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmind_thebest/core/services/session_storage_service.dart';

class OfflineSnapshotService {
  OfflineSnapshotService._();

  static const String _homeSnapshotKey = 'home_view_snapshot_v1';
  static const String _profileSnapshotKey = 'profile_view_snapshot_v1';
  static const String _analyticsSnapshotPrefix = 'analytics_view_snapshot_v1';

  static Future<void> saveHomeSnapshot(Map<String, dynamic> snapshot) async {
    await _saveScopedJson(_homeSnapshotKey, snapshot);
  }

  static Future<Map<String, dynamic>?> loadHomeSnapshot() async {
    return _loadScopedJson(_homeSnapshotKey);
  }

  static Future<void> saveProfileSnapshot(Map<String, dynamic> snapshot) async {
    await _saveScopedJson(_profileSnapshotKey, snapshot);
  }

  static Future<Map<String, dynamic>?> loadProfileSnapshot() async {
    return _loadScopedJson(_profileSnapshotKey);
  }

  static Future<void> saveAnalyticsSnapshot(
    String period,
    Map<String, dynamic> snapshot,
  ) async {
    await _saveScopedJson('$_analyticsSnapshotPrefix:$period', snapshot);
  }

  static Future<Map<String, dynamic>?> loadAnalyticsSnapshot(
    String period,
  ) async {
    return _loadScopedJson('$_analyticsSnapshotPrefix:$period');
  }

  static Future<void> _saveScopedJson(
    String baseKey,
    Map<String, dynamic> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _scopedKey(baseKey);
    if (scopedKey == null) return;
    await prefs.setString(scopedKey, jsonEncode(value));
  }

  static Future<Map<String, dynamic>?> _loadScopedJson(String baseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = await _scopedKey(baseKey);
    if (scopedKey == null) return null;

    final raw = prefs.getString(scopedKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<String?> _scopedKey(String baseKey) async {
    final userId = await SessionStorageService.getActiveUserId();
    if (userId == null) return null;
    return SessionStorageService.scopedKey(baseKey, userId);
  }
}
