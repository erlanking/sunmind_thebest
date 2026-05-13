import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmind_thebest/core/services/offline_snapshot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSnapshotService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('saves and restores home snapshot for active user', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'active_user_id': 'user-1',
      });

      const snapshot = <String, dynamic>{
        'userName': 'Erlan',
        'devices': <Map<String, dynamic>>[],
      };

      await OfflineSnapshotService.saveHomeSnapshot(snapshot);

      final restored = await OfflineSnapshotService.loadHomeSnapshot();
      expect(restored, isNotNull);
      expect(restored!['userName'], 'Erlan');
      expect(restored['devices'], isEmpty);
    });

    test('keeps snapshots isolated between users', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'active_user_id': 'user-1',
      });
      await OfflineSnapshotService.saveProfileSnapshot(<String, dynamic>{
        'name': 'First User',
      });

      SharedPreferences.setMockInitialValues(<String, Object>{
        'active_user_id': 'user-2',
        'profile_view_snapshot_v1_user-1': '{"name":"First User"}',
      });

      final restored = await OfflineSnapshotService.loadProfileSnapshot();
      expect(restored, isNull);
    });

    test('returns null when there is no active user scope', () async {
      final restored = await OfflineSnapshotService.loadAnalyticsSnapshot(
        'day',
      );
      expect(restored, isNull);
    });
  });
}
