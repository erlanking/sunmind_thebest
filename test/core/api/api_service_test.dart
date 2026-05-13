import 'package:flutter_test/flutter_test.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';

void main() {
  group('ApiService.isOfflineError', () {
    test('returns true for socket and timeout failures', () {
      expect(
        ApiService.isOfflineError(
          Exception('SocketException: No route to host'),
        ),
        isTrue,
      );
      expect(
        ApiService.isOfflineError(
          Exception('TimeoutException after 0:00:10.000000'),
        ),
        isTrue,
      );
      expect(
        ApiService.isOfflineError(
          Exception('ClientException: Failed host lookup'),
        ),
        isTrue,
      );
    });

    test('returns false for non-network errors', () {
      expect(
        ApiService.isOfflineError(Exception('HTTP 401 Unauthorized')),
        isFalse,
      );
      expect(
        ApiService.isOfflineError(Exception('Validation failed')),
        isFalse,
      );
    });
  });
}
