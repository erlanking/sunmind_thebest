import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthSession {
  final String idToken;
  final String? accessToken;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const GoogleAuthSession({
    required this.idToken,
    this.accessToken,
    required this.email,
    this.displayName,
    this.photoUrl,
  });
}

class GoogleAuthService {
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '364631840349-p6bih6a0u178298bakhddsuheajh3sto.apps.googleusercontent.com',
  );

  final GoogleSignIn _googleSignIn;

  GoogleAuthService({GoogleSignIn? googleSignIn})
    : _googleSignIn =
          googleSignIn ??
          GoogleSignIn(scopes: const ['email'], serverClientId: webClientId);

  Future<GoogleAuthSession?> signIn() async {
    try {
      _debugLog('Starting Google Sign-In');
      _debugLog('Using Web Client ID: $webClientId');

      final account = await _googleSignIn.signIn();
      if (account == null) {
        _debugLog('Google Sign-In cancelled by user');
        return null;
      }

      _debugLog('Google account selected: ${account.email}');

      final authentication = await account.authentication;
      final idToken = authentication.idToken;
      final accessToken = authentication.accessToken;

      _debugLog('Google auth resolved for: ${account.email}');
      _debugLog('Google idToken: ${_maskToken(idToken)}');
      _debugLog('Google accessToken: ${_maskToken(accessToken)}');

      if (idToken == null || idToken.trim().isEmpty) {
        _debugLog(
          'Google Sign-In failed: idToken is null or empty for ${account.email}',
        );
        await _safeDisconnect();
        throw Exception(
          'Не удалось получить Google idToken. Убедитесь, что используется Web Client ID и настроены SHA-1/SHA-256.',
        );
      }

      return GoogleAuthSession(
        idToken: idToken,
        accessToken: accessToken,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
      );
    } on PlatformException catch (error, stackTrace) {
      _debugLog(
        'Google Sign-In PlatformException: code=${error.code}, message=${error.message}, details=${error.details}',
        stackTrace: stackTrace,
      );
      throw Exception(_mapPlatformError(error));
    } catch (error) {
      _debugLog('Google Sign-In error: $error');
      throw Exception(_mapError(error));
    }
  }

  Future<void> signOut() async {
    _debugLog('Signing out from Google');
    await _safeDisconnect();
  }

  Future<void> _safeDisconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Best effort sign-out. Local app session will still be cleared.
      }
    }
  }

  String _mapPlatformError(PlatformException error) {
    if (error.code == GoogleSignIn.kSignInFailedError ||
        error.code == 'sign_in_failed') {
      return 'Google Sign-In завершился с ошибкой. Проверьте Web Client ID, SHA-1 и SHA-256.';
    }
    if (error.code == GoogleSignIn.kSignInCanceledError) {
      return 'Вход через Google отменён';
    }
    if (error.code == GoogleSignIn.kNetworkError) {
      return 'Нет соединения для входа через Google';
    }
    return error.message ?? error.code;
  }

  String _mapError(Object error) {
    final message = error.toString();
    if (message.contains('sign_in_canceled') ||
        message.contains('canceled') ||
        message.contains('cancelled')) {
      return 'Вход через Google отменён';
    }
    if (message.contains('sign_in_failed')) {
      return 'Google Sign-In завершился с ошибкой. Проверьте Web Client ID, SHA-1 и SHA-256.';
    }
    if (message.contains('network_error') || message.contains('network')) {
      return 'Нет соединения для входа через Google';
    }
    return message.replaceFirst('Exception: ', '');
  }

  void _debugLog(String message, {StackTrace? stackTrace}) {
    if (!kDebugMode) return;
    log(message, name: 'GoogleAuthService', stackTrace: stackTrace);
  }

  String _maskToken(String? value) {
    if (value == null || value.isEmpty) return '<empty>';
    if (value.length <= 16) return '***';
    return '${value.substring(0, 8)}...${value.substring(value.length - 8)}';
  }
}
