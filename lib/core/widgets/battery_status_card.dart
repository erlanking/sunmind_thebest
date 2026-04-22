import 'package:flutter/material.dart';

class BatteryStatusCard extends StatelessWidget {
  final int batteryPercent;
  final double batteryVoltage;

  const BatteryStatusCard({
    super.key,
    required this.batteryPercent,
    required this.batteryVoltage,
  });

  Color _batteryColor() {
    if (batteryPercent <= 20) return const Color(0xFFE55454);
    if (batteryPercent <= 50) return const Color(0xFFF7931A);
    return const Color(0xFF39B86D);
  }

  String _batteryState() {
    if (batteryPercent <= 20) return 'Низкий заряд';
    if (batteryPercent <= 50) return 'Средний заряд';
    return 'Нормальный заряд';
  }

  IconData _batteryIcon() {
    if (batteryPercent <= 20) return Icons.battery_alert_rounded;
    if (batteryPercent <= 50) return Icons.battery_3_bar_rounded;
    return Icons.battery_full_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _batteryColor();
    final safePercent = batteryPercent.clamp(0, 100);
    final cardColor = isDark ? const Color(0xFF0D1B2E) : const Color(0xFFF6F7FB);
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white70 : const Color(0xFF6D7481);
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFE4E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(_batteryIcon(), color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Аккумулятор',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _batteryState(),
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (batteryPercent <= 20)
                Icon(Icons.warning_amber_rounded, color: accent, size: 20),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$safePercent%',
                style: TextStyle(
                  color: accent,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${batteryVoltage.toStringAsFixed(1)} V',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: safePercent / 100,
              minHeight: 10,
              backgroundColor: trackColor,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}
