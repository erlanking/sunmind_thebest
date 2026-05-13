import 'package:flutter_test/flutter_test.dart';
import 'package:sunmind_thebest/core/services/session_storage_service.dart';

void main() {
  group('SessionStorageService', () {
    test('extractUserId falls back across known user keys', () {
      expect(
        SessionStorageService.extractUserId(<String, dynamic>{'id': 42}),
        '42',
      );
      expect(
        SessionStorageService.extractUserId(<String, dynamic>{'userId': 'abc'}),
        'abc',
      );
      expect(
        SessionStorageService.extractUserId(<String, dynamic>{'_id': 'mongo'}),
        'mongo',
      );
      expect(
        SessionStorageService.extractUserId(<String, dynamic>{
          'email': 'user@example.com',
        }),
        'user@example.com',
      );
    });

    test('extractUserId returns null for empty payload', () {
      expect(SessionStorageService.extractUserId(null), isNull);
      expect(
        SessionStorageService.extractUserId(<String, dynamic>{'id': '   '}),
        isNull,
      );
    });

    test('scopedKey normalizes unsafe characters', () {
      expect(
        SessionStorageService.scopedKey('home_view_snapshot_v1', 'user 1/test'),
        'home_view_snapshot_v1_user_1_test',
      );
    });
  });
}
