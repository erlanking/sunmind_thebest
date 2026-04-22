import 'dart:developer';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/api/mqtt_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';
import 'package:sunmind_thebest/core/services/session_restore_service.dart';
import 'package:sunmind_thebest/core/services/notification_service.dart';
import 'package:sunmind_thebest/core/theme/theme_controller.dart';
import 'package:sunmind_thebest/firebase_options.dart';
import 'package:sunmind_thebest/models/notification_model.dart';

import 'app.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel highImportanceChannel =
    AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  log('BG message id: ${message.messageId}');
  log('BG title: ${message.notification?.title}');
  log('BG body: ${message.notification?.body}');

  final model = _notificationFromRemoteMessage(message);
  if (model != null) {
    await NotificationService.saveNotification(model);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _firebaseMessagingBackgroundHandler(message);
}

NotificationType _notificationTypeFromMessage(RemoteMessage message) {
  final rawType = (message.data['type'] ?? message.data['category'] ?? '')
      .toString()
      .toLowerCase();

  if (rawType.contains('battery')) return NotificationType.battery;
  if (rawType.contains('emergency') || rawType.contains('авар')) {
    return NotificationType.emergency;
  }
  if (rawType.contains('alarm') || rawType.contains('alert')) {
    return NotificationType.alarm;
  }
  if (rawType.contains('motion')) return NotificationType.motion;
  if (rawType.contains('schedule')) return NotificationType.schedule;

  final joinedText =
      '${message.notification?.title ?? ''} ${message.notification?.body ?? ''}'
          .toLowerCase();
  if (joinedText.contains('battery') || joinedText.contains('батар')) {
    return NotificationType.battery;
  }
  if (joinedText.contains('alarm') ||
      joinedText.contains('трев') ||
      joinedText.contains('alert')) {
    return NotificationType.alarm;
  }
  if (joinedText.contains('emergency') || joinedText.contains('авар')) {
    return NotificationType.emergency;
  }
  if (joinedText.contains('motion') || joinedText.contains('движ')) {
    return NotificationType.motion;
  }
  if (joinedText.contains('schedule') || joinedText.contains('распис')) {
    return NotificationType.schedule;
  }
  return NotificationType.system;
}

NotificationModel? _notificationFromRemoteMessage(RemoteMessage message) {
  final title =
      message.notification?.title ?? message.data['title']?.toString() ?? '';
  final body =
      message.notification?.body ?? message.data['body']?.toString() ?? '';

  if (title.trim().isEmpty && body.trim().isEmpty) {
    return null;
  }

  return NotificationModel(
    id:
        message.messageId ??
        '${DateTime.now().microsecondsSinceEpoch}_${title.hashCode}_${body.hashCode}',
    title: title.isEmpty ? 'SunMind' : title,
    body: body,
    type: _notificationTypeFromMessage(message),
    timestamp: DateTime.now(),
    isRead: false,
  );
}

Future<void> _saveAndShowLocalNotification({
  required NotificationProvider provider,
  required NotificationModel model,
  bool showLocalBanner = true,
}) async {
  final saved = await provider.addNotification(model);
  if (!saved) return;

  if (!showLocalBanner) return;

  await flutterLocalNotificationsPlugin.show(
    id: model.id.hashCode,
    title: model.title,
    body: model.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        highImportanceChannel.id,
        highImportanceChannel.name,
        channelDescription: highImportanceChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final sessionRestore = await SessionRestoreService().restore();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings = InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidPlugin?.createNotificationChannel(highImportanceChannel);

  final messaging = FirebaseMessaging.instance;
  final notificationProvider = NotificationProvider();
  await notificationProvider.load();
  await messaging.setAutoInitEnabled(notificationProvider.pushNotificationsEnabled);

  if (notificationProvider.pushNotificationsEnabled) {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    log('FCM permission: ${settings.authorizationStatus}');

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final localPermissionGranted = await androidPlugin
        ?.requestNotificationsPermission();
    log('Local notifications permission: $localPermissionGranted');

    final token = await messaging.getToken();
    log(token ?? 'No FCM token');
  } else {
    log('Push notifications are disabled in local settings');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    log('FOREGROUND title: ${message.notification?.title}');
    log('FOREGROUND body: ${message.notification?.body}');

    final model = _notificationFromRemoteMessage(message);
    if (model != null) {
      await _saveAndShowLocalNotification(
        provider: notificationProvider,
        model: model,
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    log('Notification clicked');
    log('OPENED title: ${message.notification?.title}');
    log('OPENED body: ${message.notification?.body}');
  });

  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    log('App opened from terminated state by notification');
    log('INITIAL title: ${initialMessage.notification?.title}');
    log('INITIAL body: ${initialMessage.notification?.body}');
    final model = _notificationFromRemoteMessage(initialMessage);
    if (model != null) {
      await notificationProvider.addNotification(model);
    }
  }

  // ── MQTT connection notifications ──────────────────────────────────────
  MqttService().onDisconnectedCallback = () async {
    final model = NotificationModel(
      id: 'mqtt_lost_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Связь потеряна',
      body: 'Нет связи с устройствами. Проверьте Wi-Fi.',
      type: NotificationType.emergency,
      timestamp: DateTime.now(),
    );
    await notificationProvider.addNotification(model);
  };

  MqttService().onConnectedCallback = () async {
    final model = NotificationModel(
      id: 'mqtt_restored_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Связь восстановлена',
      body: 'Устройства снова в сети.',
      type: NotificationType.system,
      timestamp: DateTime.now(),
    );
    await notificationProvider.addNotification(model);
  };

  final themeController = AppThemeController();
  await themeController.loadTheme();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeController),
        ChangeNotifierProvider.value(value: notificationProvider),
      ],
      child: EasyLocalization(
        supportedLocales: const [Locale('ru'), Locale('en'), Locale('ky')],
        path: 'assets/translations',
        fallbackLocale: const Locale('ru'),
        child: SunMindApp(initialLocation: sessionRestore.initialLocation),
      ),
    ),
  );
}
