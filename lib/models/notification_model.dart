import 'dart:convert';

enum NotificationType { battery, motion, emergency, alarm, system, schedule }

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  // Маппинг иконки по типу
  static NotificationType typeFromString(String? value) {
    switch (value) {
      case 'battery':
        return NotificationType.battery;
      case 'motion':
        return NotificationType.motion;
      case 'emergency':
        return NotificationType.emergency;
      case 'alarm':
        return NotificationType.alarm;
      case 'schedule':
        return NotificationType.schedule;
      default:
        return NotificationType.system;
    }
  }

  static String typeToString(NotificationType type) {
    switch (type) {
      case NotificationType.battery:
        return 'battery';
      case NotificationType.motion:
        return 'motion';
      case NotificationType.emergency:
        return 'emergency';
      case NotificationType.alarm:
        return 'alarm';
      case NotificationType.schedule:
        return 'schedule';
      case NotificationType.system:
        return 'system';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': typeToString(type),
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        type: typeFromString(json['type'] as String?),
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );

  String toJsonString() => jsonEncode(toJson());

  factory NotificationModel.fromJsonString(String source) =>
      NotificationModel.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
