import 'package:flutter_test/flutter_test.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/features/auth/controllers/auth_controller.dart';

class _FakeApiService extends ApiService {
  _FakeApiService({this.onLogin});

  final Future<String> Function(String email, String password)? onLogin;

  @override
  Future<String> login(String email, String password) async {
    return onLogin?.call(email, password) ?? 'token';
  }

  @override
  Future<Map<String, dynamic>> me() async {
    return <String, dynamic>{
      'id': 'user-1',
      'email': 'erlan@gmail.com',
      'name': 'Erlan',
    };
  }
}

void main() {
  group('AuthController.loginWithEmail', () {
    test('stores current user on success', () async {
      final controller = AuthController(apiService: _FakeApiService());

      final user = await controller.loginWithEmail(
        email: 'erlan@gmail.com',
        password: 'secret',
      );

      expect(user.email, 'erlan@gmail.com');
      expect(controller.currentUser?.name, 'Erlan');
      expect(controller.errorMessage, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('maps offline errors to friendly message', () async {
      final controller = AuthController(
        apiService: _FakeApiService(
          onLogin: (_, _) async =>
              throw Exception('SocketException: No route to host'),
        ),
      );

      await expectLater(
        controller.loginWithEmail(email: 'erlan@gmail.com', password: 'secret'),
        throwsException,
      );

      expect(
        controller.errorMessage,
        'Не удалось связаться с сервером. Проверьте API_BASE_URL, GOOGLE_AUTH_URL и доступность backend.',
      );
      expect(controller.isLoading, isFalse);
      expect(controller.currentUser, isNull);
    });
  });
}
