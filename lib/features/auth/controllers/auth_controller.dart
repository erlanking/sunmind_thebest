import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/api/mqtt_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';
import 'package:sunmind_thebest/core/services/session_cleanup_service.dart';
import 'package:sunmind_thebest/features/auth/services/google_auth_service.dart';
import 'package:sunmind_thebest/models/user_model.dart';

class AuthController extends ChangeNotifier {
  final ApiService _apiService;
  final GoogleAuthService _googleAuthService;

  AuthController({ApiService? apiService, GoogleAuthService? googleAuthService})
    : _apiService = apiService ?? ApiService(),
      _googleAuthService = googleAuthService ?? GoogleAuthService();

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;

  Future<UserModel> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return _run<UserModel>(() async {
      _debugLog('Starting email login for $email');
      await _apiService.login(email, password);
      final user = UserModel.fromJson(await _apiService.me());
      _currentUser = user;
      _debugLog('Email login completed for ${user.email}');
      return user;
    });
  }

  Future<UserModel> loginWithGoogle() async {
    return _run<UserModel>(() async {
      _debugLog('Starting Google login');
      final googleSession = await _googleAuthService.signIn();
      if (googleSession == null) {
        _debugLog('Google login cancelled before backend request');
        throw Exception('Вход через Google отменён');
      }

      _debugLog(
        'Google login succeeded locally for ${googleSession.email}. Sending idToken to backend.',
      );
      final user = await _apiService.loginWithGoogle(
        idToken: googleSession.idToken,
        accessToken: googleSession.accessToken,
        email: googleSession.email,
      );
      _currentUser = user;
      _debugLog('Backend JWT login completed for ${user.email}');
      return user;
    });
  }

  Future<void> logout({
    NotificationProvider? notificationProvider,
    MqttService? mqttService,
  }) async {
    await _run<void>(() async {
      _debugLog('Starting logout');
      await _googleAuthService.signOut();
      await SessionCleanupService.clearSessionData(
        notificationProvider: notificationProvider,
        mqttService: mqttService,
      );
      _currentUser = null;
      _debugLog('Logout completed');
    });
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final result = await action();
      return result;
    } catch (error) {
      _errorMessage = _normalizeError(error);
      _debugLog('Auth error: $_errorMessage');
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  String _normalizeError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    final normalized = message.toLowerCase();

    if (normalized.contains('google authentication is not configured')) {
      return 'Вход через Google не настроен на сервере';
    }
    if (normalized.contains('socket') ||
        normalized.contains('clientexception') ||
        normalized.contains('failed host lookup') ||
        normalized.contains("couldn't connect") ||
        normalized.contains('connection refused') ||
        normalized.contains('timed out')) {
      return 'Не удалось связаться с сервером. Проверьте API_BASE_URL, GOOGLE_AUTH_URL и доступность backend.';
    }
    if (normalized.contains('401') || normalized.contains('403')) {
      return 'Не удалось выполнить вход. Проверьте аккаунт.';
    }
    return message;
  }

  void _debugLog(String message) {
    if (!kDebugMode) return;
    log(message, name: 'AuthController');
  }
}
