import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';
import 'package:sunmind_thebest/models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().load();
    });
  }

  /// Иконка по типу уведомления
  IconData _iconForType(NotificationType type) {
    switch (type) {
      case NotificationType.battery:
        return Icons.battery_charging_full_outlined;
      case NotificationType.motion:
        return Icons.motion_photos_on_outlined;
      case NotificationType.emergency:
        return Icons.warning_amber_rounded;
      case NotificationType.alarm:
        return Icons.notification_important_outlined;
      case NotificationType.schedule:
        return Icons.schedule_outlined;
      case NotificationType.system:
        return Icons.wb_sunny_outlined;
    }
  }

  /// Форматирование времени
  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Сейчас';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays == 1) return 'Вчера';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final card = isDark ? const Color(0xFF171A1F) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF161A22);
    final muted = isDark ? const Color(0xFF858A95) : const Color(0xFF6D7481);
    const accent = Color(0xFFF6C343);

    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final notifications = provider.notifications;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: Row(
              children: [
                const Text('Уведомления'),
                if (provider.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${provider.unreadCount}',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (notifications.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: isDark
                            ? const Color(0xFF171A1F)
                            : Colors.white,
                        title: Text(
                          'Очистить всё?',
                          style: TextStyle(color: text),
                        ),
                        content: Text(
                          'Все уведомления будут удалены.',
                          style: TextStyle(color: muted),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Отмена',
                              style: TextStyle(color: muted),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Удалить',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await context.read<NotificationProvider>().clearAll();
                    }
                  },
                  child: Text(
                    'Очистить',
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ),
            ],
          ),

          // ─── Body ───────────────────────────────────────────────────────
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none_outlined,
                        size: 56,
                        color: muted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Пока уведомлений нет',
                        style: TextStyle(color: muted, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final isUnread = !item.isRead;

                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                      ),
                      onDismissed: (_) {
                        context.read<NotificationProvider>().deleteNotification(
                          item.id,
                        );
                      },
                      child: GestureDetector(
                        onTap: () {
                          if (isUnread) {
                            context.read<NotificationProvider>().markAsRead(
                              item.id,
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(20),
                            border: isUnread
                                ? Border.all(
                                    color: accent.withValues(alpha: 0.5),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Иконка
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _iconForType(item.type),
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Текст
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontWeight: isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: text,
                                            ),
                                          ),
                                        ),
                                        if (isUnread)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin: const EdgeInsets.only(
                                              left: 4,
                                              top: 2,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: accent,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.body,
                                      style: TextStyle(
                                        color: muted,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Время
                              Text(
                                _formatTime(item.timestamp),
                                style: TextStyle(color: muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
