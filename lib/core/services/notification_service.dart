import 'package:sunmind_thebest/core/services/app_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmind_thebest/core/services/session_storage_service.dart';
import 'package:sunmind_thebest/models/notification_model.dart';

class NotificationService {
  static const String legacyStorageKey = 'sunmind_notifications';
  static final AppSettingsService _settings = AppSettingsService();

  /// Сохранить уведомление (новые добавляются в начало)
  static Future<bool> saveNotification(NotificationModel notification) async {
    if (!await _shouldStoreNotification(notification)) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = await _resolveStorageKey(prefs);
    if (key == null) return false;

    final raw = prefs.getStringList(key) ?? [];
    final filtered = raw.where((item) {
      try {
        final model = NotificationModel.fromJsonString(item);
        return model.id != notification.id;
      } catch (_) {
        return false;
      }
    }).toList();

    filtered.insert(0, notification.toJsonString());

    // Ограничиваем 100 уведомлениями
    if (filtered.length > 100) filtered.removeLast();

    await prefs.setStringList(key, filtered);
    return true;
  }

  /// Получить все уведомления (новые сверху)
  static Future<List<NotificationModel>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _resolveStorageKey(prefs);
    if (key == null) return [];

    final raw = prefs.getStringList(key) ?? [];
    final items = <NotificationModel>[];
    for (final item in raw) {
      try {
        items.add(NotificationModel.fromJsonString(item));
      } catch (_) {
        // Пропускаем битые записи, чтобы экран уведомлений не падал.
      }
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  /// Отметить одно уведомление как прочитанное
  static Future<void> markAsRead(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _resolveStorageKey(prefs);
    if (key == null) return;

    final raw = prefs.getStringList(key) ?? [];

    final updated = raw.map((s) {
      final model = NotificationModel.fromJsonString(s);
      if (model.id == id) {
        model.isRead = true;
        return model.toJsonString();
      }
      return s;
    }).toList();

    await prefs.setStringList(key, updated);
  }

  /// Удалить одно уведомление
  static Future<void> deleteNotification(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _resolveStorageKey(prefs);
    if (key == null) return;

    final raw = prefs.getStringList(key) ?? [];
    final updated = raw.where((s) {
      final model = NotificationModel.fromJsonString(s);
      return model.id != id;
    }).toList();
    await prefs.setStringList(key, updated);
  }

  /// Удалить все уведомления
  static Future<void> clearAll({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final targetUserId = userId ?? await SessionStorageService.getActiveUserId();
    if (targetUserId != null) {
      await prefs.remove(
        SessionStorageService.scopedKey(legacyStorageKey, targetUserId),
      );
    }
    await prefs.remove(legacyStorageKey);
  }

  /// Количество непрочитанных
  static Future<int> unreadCount() async {
    final list = await getNotifications();
    return list.where((n) => !n.isRead).length;
  }

  static Future<bool> hasActiveUser() async {
    return SessionStorageService.hasActiveUser();
  }

  static Future<String?> _resolveStorageKey(SharedPreferences prefs) async {
    final userId = await SessionStorageService.getActiveUserId();
    if (userId == null) return null;

    final scopedKey = SessionStorageService.scopedKey(legacyStorageKey, userId);
    if (!prefs.containsKey(scopedKey) && prefs.containsKey(legacyStorageKey)) {
      final legacyValue = prefs.get(legacyStorageKey);
      if (legacyValue is List) {
        await prefs.setStringList(
          scopedKey,
          legacyValue.map((item) => item.toString()).toList(),
        );
      }
      await prefs.remove(legacyStorageKey);
    }
    return scopedKey;
  }

  static Future<bool> _shouldStoreNotification(NotificationModel notification) async {
    final pushEnabled = await _settings.getPushNotificationsEnabled();
    if (!pushEnabled) return false;

    final emergencyEnabled = await _settings.getEmergencyAlertsEnabled();
    if (!emergencyEnabled && _isEmergencyType(notification.type)) {
      return false;
    }

    return true;
  }

  static bool _isEmergencyType(NotificationType type) {
    return type == NotificationType.motion ||
        type == NotificationType.emergency ||
        type == NotificationType.alarm;
  }
}
