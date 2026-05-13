import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF17171B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final mutedColor = isDark ? const Color(0xFF6E6E75) : const Color(0xFF8E8E93);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          'Уведомления',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(title: 'Общие', color: mutedColor),
          _Card(
            color: cardBg,
            children: [
              _SwitchTile(
                icon: Icons.notifications_active_outlined,
                title: 'Push-уведомления',
                subtitle: 'Получать уведомления на телефон',
                value: notificationProvider.pushNotificationsEnabled,
                textColor: textColor,
                mutedColor: mutedColor,
                onChanged: (v) =>
                    context.read<NotificationProvider>().setPushNotificationsEnabled(v),
              ),
              _Divider(color: mutedColor),
              _SwitchTile(
                icon: Icons.warning_amber_rounded,
                title: 'Экстренные сигналы',
                subtitle: 'Критические ошибки и аварии',
                value: notificationProvider.emergencyAlertsEnabled,
                textColor: textColor,
                mutedColor: mutedColor,
                onChanged: (v) =>
                    context.read<NotificationProvider>().setEmergencyAlertsEnabled(v),
              ),
            ],
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'Батарея', color: mutedColor),
          _Card(
            color: cardBg,
            children: [
              _InfoTile(
                icon: Icons.battery_alert_outlined,
                iconColor: const Color(0xFFFF3B30),
                title: 'Критический заряд (<15%)',
                subtitle: 'Уведомление при ERROR статусе',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              _Divider(color: mutedColor),
              _InfoTile(
                icon: Icons.battery_3_bar_outlined,
                iconColor: const Color(0xFFFFCC00),
                title: 'Низкий заряд (<30%)',
                subtitle: 'Уведомление при WARNING статусе',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
            ],
          ),

          const SizedBox(height: 20),
          _SectionHeader(title: 'Устройства', color: mutedColor),
          _Card(
            color: cardBg,
            children: [
              _InfoTile(
                icon: Icons.shield_moon_outlined,
                iconColor: const Color(0xFF64D2FF),
                title: 'Охранный режим',
                subtitle: 'При обнаружении движения ночью',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              _Divider(color: mutedColor),
              _InfoTile(
                icon: Icons.build_circle_outlined,
                iconColor: const Color(0xFFFFD54F),
                title: 'Техническое обслуживание',
                subtitle: 'Напоминание каждые 30 дней',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
              _Divider(color: mutedColor),
              _InfoTile(
                icon: Icons.wifi_off_outlined,
                iconColor: const Color(0xFFFF3B30),
                title: 'Устройство офлайн',
                subtitle: 'Нет связи более 2 минут',
                textColor: textColor,
                mutedColor: mutedColor,
              ),
            ],
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFFD54F).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFFFFD54F),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Уведомления отправляются автоматически с сервера при наступлении триггерных событий. Настройка типов уведомлений производится через включение/выключение соответствующих режимов в настройках устройства.',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final Color color;
  const _Card({required this.children, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 52,
      endIndent: 16,
      color: color.withValues(alpha: 0.3),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color textColor;
  final Color mutedColor;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: mutedColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFFD54F),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color mutedColor;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: iconColor.withValues(alpha: 0.7), size: 18),
        ],
      ),
    );
  }
}
