import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStorageService {
  static const String accessTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'auth_user';
  static const String activeUserIdKey = 'active_user_id';
  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static const IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  static Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final secureToken = await _secureStorage.read(key: accessTokenKey);
    if (secureToken != null && secureToken.trim().isNotEmpty) {
      return secureToken;
    }

    final legacyToken = prefs.getString(accessTokenKey);
    if (legacyToken != null && legacyToken.trim().isNotEmpty) {
      await _secureStorage.write(key: accessTokenKey, value: legacyToken);
      await prefs.remove(accessTokenKey);
      return legacyToken;
    }

    return null;
  }

  static Future<String?> readRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final secureToken = await _secureStorage.read(key: refreshTokenKey);
    if (secureToken != null && secureToken.trim().isNotEmpty) {
      return secureToken;
    }

    final legacyToken = prefs.getString(refreshTokenKey);
    if (legacyToken != null && legacyToken.trim().isNotEmpty) {
      await _secureStorage.write(key: refreshTokenKey, value: legacyToken);
      await prefs.remove(refreshTokenKey);
      return legacyToken;
    }

    return null;
  }

  static Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    Map<String, dynamic>? user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: accessTokenKey, value: accessToken);
    await prefs.remove(accessTokenKey);

    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      await _secureStorage.write(key: refreshTokenKey, value: refreshToken);
      await prefs.remove(refreshTokenKey);
    } else {
      await _secureStorage.delete(key: refreshTokenKey);
      await prefs.remove(refreshTokenKey);
    }

    if (user != null) {
      await cacheUser(user);
    } else {
      await prefs.remove(userKey);
      await prefs.remove(activeUserIdKey);
    }
  }

  static Future<void> cacheUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userKey, jsonEncode(user));

    final userId = extractUserId(user);
    if (userId != null) {
      await prefs.setString(activeUserIdKey, userId);
    }
  }

  static Future<Map<String, dynamic>?> readCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(userKey);
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
      // Ignore malformed cache entries and let the app reload the profile.
    }
    return null;
  }

  static Future<String?> getActiveUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(activeUserIdKey);
  }

  static Future<bool> hasActiveUser() async {
    return (await getActiveUserId()) != null;
  }

  static Future<void> clearSessionMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: accessTokenKey);
    await _secureStorage.delete(key: refreshTokenKey);
    await prefs.remove(accessTokenKey);
    await prefs.remove(refreshTokenKey);
    await prefs.remove(userKey);
    await prefs.remove(activeUserIdKey);
  }

  static String scopedKey(String baseKey, String userId) {
    return '${baseKey}_${_normalizeUserScope(userId)}';
  }

  static String? extractUserId(Map<String, dynamic>? user) {
    if (user == null) return null;

    final raw =
        user['id'] ??
        user['userId'] ??
        user['_id'] ??
        user['uuid'] ??
        user['email'];

    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String _normalizeUserScope(String value) {
    return value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }
}
