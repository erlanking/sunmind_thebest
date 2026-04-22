import 'dart:convert';
import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sunmind_thebest/models/user_model.dart';
import 'package:sunmind_thebest/core/services/session_storage_service.dart';

/// Простенький клиент для работы с бекендом SunMind.
class ApiService {
  /// Базовый URL берём из dart-define `API_BASE_URL`, иначе локальный сервер.
  /// Пример запуска: flutter run --dart-define=API_BASE_URL=http://192.168.50.199:5000
  static const String _baseUrlFromEnvironment = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://172.20.10.2:5001',
  );
  static const String _googleAuthUrlFromEnvironment = String.fromEnvironment(
    'GOOGLE_AUTH_URL',
    defaultValue: '',
  );

  static String get baseUrl => _normalizeUrl(_baseUrlFromEnvironment);

  /// По умолчанию используем общий baseUrl, чтобы auth-роуты не расходились
  /// между обычным логином и входом через Google.
  static String get googleAuthUrl {
    final override = _googleAuthUrlFromEnvironment.trim();
    if (override.isNotEmpty) {
      return _normalizeUrl(override);
    }
    return '$baseUrl/auth/google';
  }

  static String _normalizeUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static String _buildUrl(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalizedPath';
  }

  Future<String?> _readToken() async {
    return SessionStorageService.readAccessToken();
  }

  Future<void> clearToken() async {
    await SessionStorageService.clearSessionMetadata();
  }

  Future<http.Response> _request(
    String path, {
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse(_buildUrl(path));
    final token = await _readToken();

    final mergedHeaders = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };

    http.Response res;
    switch (method) {
      case 'POST':
        res = await http
            .post(uri, headers: mergedHeaders, body: body)
            .timeout(const Duration(seconds: 10));
        break;
      case 'GET':
        res = await http
            .get(uri, headers: mergedHeaders)
            .timeout(const Duration(seconds: 10));
        break;
      case 'PUT':
        res = await http
            .put(uri, headers: mergedHeaders, body: body)
            .timeout(const Duration(seconds: 10));
        break;
      case 'PATCH':
        res = await http
            .patch(uri, headers: mergedHeaders, body: body)
            .timeout(const Duration(seconds: 10));
        break;
      case 'DELETE':
        res = await http
            .delete(uri, headers: mergedHeaders, body: body)
            .timeout(const Duration(seconds: 10));
        break;
      default:
        throw UnimplementedError('HTTP $method not implemented');
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res;
    }

    final snippet = res.body.length > 300
        ? res.body.substring(0, 300)
        : res.body;
    throw Exception(
      'HTTP ${res.statusCode} ${res.reasonPhrase} for $path\n$snippet',
    );
  }

  Future<http.Response> _requestWithFallback(
    List<String> paths, {
    String method = 'GET',
    Map<String, String>? headers,
    Object? body,
    bool retryOnTransientFailure = false,
  }) async {
    final failures = <String>[];
    for (final p in paths) {
      try {
        final res = await _request(
          p,
          method: method,
          headers: headers,
          body: body,
        );
        return res;
      } catch (e) {
        final shouldTryNext =
            (e is Exception && e.toString().contains('HTTP 404')) ||
            (retryOnTransientFailure && _isTransientFailure(e));

        failures.add('${_buildUrl(p)} -> ${_formatError(e)}');
        _debugLog('Request failed for ${_buildUrl(p)}: ${_formatError(e)}');

        if (shouldTryNext && p != paths.last) {
          // Пробуем следующий путь, если маршрут не найден
          // или текущая попытка завершилась сетевой/временной ошибкой.
          continue;
        }
        break;
      }
    }

    throw Exception(
      'Запрос не выполнен. Проверены пути:\n${failures.join('\n')}',
    );
  }

  Future<String> login(String email, String password) async {
    final res = await _requestWithFallback(
      ['/auth/login', '/api/auth/login'],
      method: 'POST',
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = await _storeAuthSession(data, statusCode: res.statusCode);
    final user = _extractUser(_unwrapPayload(data)) ?? _extractUser(data);

    if (user == null) {
      try {
        await me();
      } catch (_) {
        // If profile lookup fails, the app will retry later.
      }
    }
    return token;
  }

  Future<UserModel> loginWithGoogle({
    required String idToken,
    String? accessToken,
    String? email,
  }) async {
    final body = jsonEncode({
      'idToken': idToken,
      'credential': idToken,
      'token': idToken,
      if (accessToken != null && accessToken.isNotEmpty)
        'accessToken': accessToken,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    _debugLog('Sending Google idToken to backend: ${_maskToken(idToken)}');
    if (accessToken != null && accessToken.isNotEmpty) {
      _debugLog(
        'Sending Google accessToken to backend: ${_maskToken(accessToken)}',
      );
    }
    _debugLog('API base URL: $baseUrl');
    _debugLog('Google backend endpoint: $googleAuthUrl');

    final hasCustomGoogleUrl = _googleAuthUrlFromEnvironment.trim().isNotEmpty;
    final res = hasCustomGoogleUrl
        ? await http
              .post(
                Uri.parse(googleAuthUrl),
                headers: const {'Content-Type': 'application/json'},
                body: body,
              )
              .timeout(const Duration(seconds: 15))
        : await _requestWithFallback(
            ['/auth/google', '/api/auth/google'],
            method: 'POST',
            body: body,
            retryOnTransientFailure: true,
          );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final snippet = res.body.length > 300
          ? res.body.substring(0, 300)
          : res.body;
      _debugLog(
        'Google backend auth failed: ${res.statusCode} ${res.reasonPhrase}',
      );
      _debugLog('Google backend response body: $snippet');
      throw Exception(
        'HTTP ${res.statusCode} ${res.reasonPhrase} for /auth/google\n$snippet',
      );
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final jwt = await _storeAuthSession(data, statusCode: res.statusCode);
    final userJson = _extractUser(_unwrapPayload(data)) ?? _extractUser(data);
    if (userJson == null) {
      _debugLog('Google backend auth failed: user payload missing');
      throw Exception('Ответ сервера не содержит данные пользователя');
    }

    _debugLog('Backend JWT received: $jwt');
    _debugLog('Backend user payload: ${jsonEncode(userJson)}');
    return UserModel.fromJson(userJson);
  }

  Future<void> register(String name, String email, String password) async {
    await _requestWithFallback(
      ['/auth/register', '/api/auth/register'],
      method: 'POST',
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _requestWithFallback(['/auth/me', '/api/auth/me']);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final normalizedUser = _extractUser(data) ?? data;
    await SessionStorageService.cacheUser(normalizedUser);
    return normalizedUser;
  }

  Future<String> _storeAuthSession(
    Map<String, dynamic> data, {
    required int statusCode,
  }) async {
    final payload = _unwrapPayload(data);
    final token = _extractAccessToken(payload) ?? _extractAccessToken(data);
    if (token == null || token.isEmpty) {
      throw Exception('Не удалось получить токен (status $statusCode)');
    }

    final refreshToken =
        _extractRefreshToken(payload) ?? _extractRefreshToken(data);
    final user = _extractUser(payload) ?? _extractUser(data);

    await SessionStorageService.saveSession(
      accessToken: token,
      refreshToken: refreshToken,
      user: user,
    );
    return token;
  }

  Map<String, dynamic> _unwrapPayload(Map<String, dynamic> data) {
    final nested = data['data'];
    if (nested is Map<String, dynamic>) return nested;
    if (nested is Map) return nested.cast<String, dynamic>();
    return data;
  }

  String? _extractAccessToken(Map<String, dynamic> data) {
    final value =
        data['access_token'] ??
        data['accessToken'] ??
        data['token'] ??
        data['jwt'] ??
        data['jwtToken'];
    return value?.toString();
  }

  String? _extractRefreshToken(Map<String, dynamic> data) {
    final value = data['refresh_token'] ?? data['refreshToken'];
    return value?.toString();
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    log(message, name: 'ApiService');
  }

  String _maskToken(String value) {
    if (value.isEmpty) return '<empty>';
    if (value.length <= 16) return '***';
    return '${value.substring(0, 8)}...${value.substring(value.length - 8)}';
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final body = jsonEncode({
      'currentPassword': currentPassword,
      'oldPassword': currentPassword,
      'password': newPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
      'newPasswordConfirm': confirmPassword,
    });

    const postPaths = [
      '/api/Auth/changePassword',
      '/api/auth/changePassword',
      '/api/auth/change-password',
      '/auth/changePassword',
      '/auth/change-password',
    ];

    const putPaths = [
      '/api/Auth/changePassword',
      '/api/auth/changePassword',
      '/api/auth/change-password',
      '/auth/changePassword',
      '/auth/change-password',
    ];

    try {
      await _requestWithFallback(postPaths, method: 'POST', body: body);
      return;
    } catch (e) {
      if (!_isRouteMismatch(e)) rethrow;
    }

    try {
      await _requestWithFallback(putPaths, method: 'PUT', body: body);
      return;
    } catch (e) {
      if (_isRouteMismatch(e)) {
        throw UnsupportedError('Change password endpoint is unavailable');
      }
      rethrow;
    }
  }

  Map<String, dynamic>? _extractUser(Map<String, dynamic> data) {
    final rawUser = data['user'] ?? data['profile'] ?? data['me'];
    if (rawUser is Map<String, dynamic>) {
      return rawUser;
    }
    if (rawUser is Map) {
      return rawUser.cast<String, dynamic>();
    }
    return null;
  }

  bool _isRouteMismatch(Object error) {
    final message = error.toString();
    return message.contains('HTTP 404') || message.contains('HTTP 405');
  }

  bool _isTransientFailure(Object error) {
    final message = _formatError(error).toLowerCase();
    return message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('socket') ||
        message.contains('connection refused') ||
        message.contains("couldn't connect") ||
        message.contains('failed host lookup') ||
        message.contains('clientexception');
  }

  String _formatError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<Map<String, dynamic>> fullStatus() async {
    final res = await _requestWithFallback([
      '/light/status',
      '/api/light/status',
      '/led/full-status',
      '/api/led/full-status',
    ]);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> setLed(bool on) async {
    final onPaths = [
      '/light/on',
      '/api/light/on',
      '/led/led/on',
      '/api/led/led/on',
    ];
    final offPaths = [
      '/light/off',
      '/api/light/off',
      '/led/led/off',
      '/api/led/led/off',
    ];

    try {
      await _requestWithFallback(on ? onPaths : offPaths, method: 'POST');
      return;
    } catch (e) {
      // если все 404 — пробуем универсальный /led/led
      await _requestWithFallback(
        ['/led/led', '/api/led/led'],
        method: 'POST',
        body: jsonEncode({'state': on}),
      );
    }
  }

  Future<void> setDeviceLed(String deviceId, bool on) async {
    final payload = jsonEncode({
      'deviceId': deviceId,
      'state': on,
      'on': on,
      'power': on,
      'ledState': on ? 'ON' : 'OFF',
      'led_state': on ? 'ON' : 'OFF',
    });

    try {
      await _request(
        '/api/devices/$deviceId/control',
        method: 'POST',
        body: payload,
      );
      return;
    } catch (_) {
      await _requestWithFallback(
        [
          '/api/devices/$deviceId/led',
          '/api/devices/$deviceId/power',
          '/api/device/$deviceId/control',
          '/devices/$deviceId/control',
        ],
        method: 'POST',
        body: payload,
        retryOnTransientFailure: true,
      );
    }
  }

  Future<void> setDevicesLed(List<String> deviceIds, bool on) async {
    final targets = deviceIds
        .where((id) => id.trim().isNotEmpty)
        .toSet()
        .toList();
    if (targets.isEmpty) {
      throw Exception('Нет устройств для управления');
    }

    for (final deviceId in targets) {
      await setDeviceLed(deviceId, on);
    }
  }

  Future<void> toggleLed() async {
    await _requestWithFallback([
      '/light/toggle',
      '/api/light/toggle',
      '/led/toggle',
      '/api/led/toggle',
    ], method: 'POST');
  }

  Future<void> setMode(String mode) async {
    await _requestWithFallback(
      ['/light/mode', '/api/light/mode', '/led/mode', '/api/led/mode'],
      method: 'POST',
      body: jsonEncode({'mode': mode}),
    );
  }

  Future<void> setBrightness(double value) async {
    await _requestWithFallback(
      ['/light/brightness', '/api/light/brightness'],
      method: 'POST',
      body: jsonEncode({'value': value.round()}),
    );
  }

  // ---- Device v2 API ----
  Future<Map<String, dynamic>> getDeviceStatus(String deviceId) async {
    final res = await _request('/api/devices/$deviceId/status');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final res = await _request('/api/devices');
    return _decodeListResponse(res.body, endpoint: '/api/devices');
  }

  Future<void> updateDevice(String deviceId, {required String name}) async {
    await _request(
      '/api/devices/$deviceId',
      method: 'PATCH',
      body: jsonEncode({'name': name}),
    );
  }

  Future<void> deleteDevice(String deviceId) async {
    await _request('/api/devices/$deviceId', method: 'DELETE');
  }

  Future<Map<String, dynamic>> getDeviceSchedule(String deviceId) async {
    final res = await _request('/api/devices/$deviceId/schedule');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> updateDeviceSchedule(
    String deviceId, {
    required int onHour,
    required int onMinute,
    required int offHour,
    required int offMinute,
  }) async {
    await _request(
      '/api/devices/$deviceId/schedule',
      method: 'POST',
      body: jsonEncode({
        'onHour': onHour,
        'onMinute': onMinute,
        'offHour': offHour,
        'offMinute': offMinute,
      }),
    );
  }

  Future<List<Map<String, dynamic>>> getTelemetry(
    String deviceId, {
    String period = 'day',
  }) async {
    final res = await _request(
      '/api/devices/$deviceId/telemetry?period=$period',
    );
    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw Exception('Некорректный ответ telemetry');
  }

  Future<Map<String, dynamic>> getAnalyticsSummary(
    String deviceId, {
    String period = 'day',
  }) async {
    final res = await _request(
      '/api/devices/$deviceId/analytics?period=$period',
    );
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> registerDevice({
    required String deviceId,
    required String zoneName,
  }) async {
    await _request(
      '/api/devices/register',
      method: 'POST',
      body: jsonEncode({'deviceId': deviceId, 'zoneName': zoneName}),
    );
  }

  Future<List<Map<String, dynamic>>> getZones() async {
    final res = await _request('/api/zones');
    return _decodeListResponse(res.body, endpoint: '/api/zones');
  }

  Future<Map<String, dynamic>> createZone({required String name}) async {
    final res = await _request(
      '/api/zones',
      method: 'POST',
      body: jsonEncode({'name': name}),
    );
    final decoded = jsonDecode(res.body);
    if (decoded is Map<String, dynamic>) {
      return _unwrapPayload(decoded);
    }
    if (decoded is Map) {
      return _unwrapPayload(decoded.cast<String, dynamic>());
    }
    throw Exception('Некорректный ответ /api/zones');
  }

  Future<void> updateZone(String zoneId, {required String name}) async {
    await _request(
      '/api/zones/$zoneId',
      method: 'PATCH',
      body: jsonEncode({'name': name}),
    );
  }

  Future<void> deleteZone(String zoneId) async {
    await _request('/api/zones/$zoneId', method: 'DELETE');
  }

  Future<void> addDevicesToZone(
    String zoneId, {
    required List<String> deviceIds,
  }) async {
    await _request(
      '/api/zones/$zoneId/devices',
      method: 'POST',
      body: jsonEncode({'deviceIds': deviceIds}),
    );
  }

  Future<void> removeDeviceFromZone(String zoneId, String deviceId) async {
    await _request('/api/zones/$zoneId/devices/$deviceId', method: 'DELETE');
  }

  Future<void> controlZone(String zoneId, {required bool on}) async {
    await _request(
      '/api/zones/$zoneId/control',
      method: 'POST',
      body: jsonEncode({
        'state': on,
        'on': on,
        'power': on,
        'ledState': on ? 'ON' : 'OFF',
        'led_state': on ? 'ON' : 'OFF',
      }),
    );
  }

  Future<void> setDeviceBrightness(String deviceId, int brightness) async {
    await _request(
      '/api/devices/$deviceId/control',
      method: 'POST',
      body: jsonEncode({'brightness': brightness}),
    );
  }

  Future<void> setDeviceMode(String deviceId, {required bool manual}) async {
    await _request(
      '/api/devices/$deviceId/control',
      method: 'POST',
      body: jsonEncode({
        'manual_mode': manual,
        'manualMode': manual,
        'mode': manual ? 'manual' : 'auto',
      }),
    );
  }

  List<Map<String, dynamic>> _decodeListResponse(
    String body, {
    required String endpoint,
  }) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final payload =
          decoded['data'] ??
          decoded['items'] ??
          decoded['zones'] ??
          decoded['devices'];
      if (payload is List) {
        return payload
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }
    if (decoded is Map) {
      final normalized = decoded.cast<String, dynamic>();
      final payload =
          normalized['data'] ??
          normalized['items'] ??
          normalized['zones'] ??
          normalized['devices'];
      if (payload is List) {
        return payload
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }
    throw Exception('Некорректный ответ $endpoint');
  }
}
