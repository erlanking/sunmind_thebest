import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sunmind_thebest/core/services/app_settings_service.dart';
import 'package:sunmind_thebest/core/services/notification_service.dart';
import 'package:sunmind_thebest/models/notification_model.dart';

/// Provider для управления списком уведомлений в UI.
/// Используется в NotificationsScreen через ChangeNotifierProvider.
class NotificationProvider extends ChangeNotifier {
  final AppSettingsService _settings = AppSettingsService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _emergencyAlertsEnabled = true;
  bool _pushNotificationsEnabled = true;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get emergencyAlertsEnabled => _emergencyAlertsEnabled;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;

  /// Загружает уведомления из SharedPreferences
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    await loadSettings(notifyListenersAfterLoad: false);
    _notifications = await NotificationService.getNotifications();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSettings({bool notifyListenersAfterLoad = true}) async {
    _emergencyAlertsEnabled = await _settings.getEmergencyAlertsEnabled();
    _pushNotificationsEnabled = await _settings.getPushNotificationsEnabled();

    if (notifyListenersAfterLoad) {
      notifyListeners();
    }
  }

  Future<void> setEmergencyAlertsEnabled(bool value) async {
    await _settings.setEmergencyAlertsEnabled(value);
    _emergencyAlertsEnabled = value;
    notifyListeners();
  }

  Future<void> setPushNotificationsEnabled(bool value) async {
    await _settings.setPushNotificationsEnabled(value);
    _pushNotificationsEnabled = value;

    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(value);
      if (value) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }
    } catch (_) {
      // Keep local preference even if the platform API is unavailable.
    }

    notifyListeners();
  }

  /// Добавляет и сохраняет новое уведомление (вызывается из main.dart при получении push)
  Future<bool> addNotification(NotificationModel notification) async {
    final saved = await NotificationService.saveNotification(notification);
    if (!saved) return false;

    _notifications.removeWhere((n) => n.id == notification.id);
    _notifications.insert(0, notification);
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();
    return true;
  }

  /// Отмечает уведомление как прочитанное
  Future<void> markAsRead(String id) async {
    await NotificationService.markAsRead(id);
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      notifyListeners();
    }
  }

  /// Удаляет одно уведомление
  Future<void> deleteNotification(String id) async {
    await NotificationService.deleteNotification(id);
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Удаляет все уведомления
  Future<void> clearAll() async {
    await NotificationService.clearAll();
    _notifications = [];
    notifyListeners();
  }

  void clearInMemory() {
    _notifications = [];
    _isLoading = false;
    notifyListeners();
  }
}
