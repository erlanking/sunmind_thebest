import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/session_cleanup_service.dart';
import 'package:sunmind_thebest/core/services/session_storage_service.dart';

class SessionRestoreResult {
  final bool hasStoredToken;
  final bool isAuthenticated;

  const SessionRestoreResult({
    required this.hasStoredToken,
    required this.isAuthenticated,
  });

  String get initialLocation {
    if (isAuthenticated) return '/home';
    if (hasStoredToken) return '/login';
    return '/onboarding';
  }
}

class SessionRestoreService {
  final ApiService _api;

  SessionRestoreService({ApiService? api}) : _api = api ?? ApiService();

  Future<SessionRestoreResult> restore() async {
    final token = await SessionStorageService.readAccessToken();
    final hasStoredToken = token != null && token.trim().isNotEmpty;

    if (!hasStoredToken) {
      return const SessionRestoreResult(
        hasStoredToken: false,
        isAuthenticated: false,
      );
    }

    try {
      await _api.me();
      return const SessionRestoreResult(
        hasStoredToken: true,
        isAuthenticated: true,
      );
    } catch (_) {
      await SessionCleanupService.clearSessionData();
      return const SessionRestoreResult(
        hasStoredToken: true,
        isAuthenticated: false,
      );
    }
  }
}
