import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';

class NightGuardScheduleScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final int initialStartHour;
  final int initialStartMinute;
  final int initialEndHour;
  final int initialEndMinute;

  const NightGuardScheduleScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.initialStartHour = 22,
    this.initialStartMinute = 0,
    this.initialEndHour = 6,
    this.initialEndMinute = 0,
  });

  @override
  State<NightGuardScheduleScreen> createState() =>
      _NightGuardScheduleScreenState();
}

class _NightGuardScheduleScreenState extends State<NightGuardScheduleScreen> {
  final ApiService _api = ApiService();
  bool _saving = false;

  late int _startHour;
  late int _startMinute;
  late int _endHour;
  late int _endMinute;

  @override
  void initState() {
    super.initState();
    _startHour = widget.initialStartHour;
    _startMinute = widget.initialStartMinute;
    _endHour = widget.initialEndHour;
    _endMinute = widget.initialEndMinute;
  }

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() => _saving = true);
    HapticService.medium();
    try {
      await _api.setNightGuardSchedule(
        widget.deviceId,
        startHour: _startHour,
        startMinute: _startMinute,
        endHour: _endHour,
        endMinute: _endMinute,
      );
      if (mounted) {
        HapticService.success();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.isOfflineError(e)
                  ? 'Нет интернета. Проверьте подключение.'
                  : 'Не удалось сохранить. Попробуйте ещё раз.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pickTime({
    required bool isStart,
    required int hour,
    required int minute,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      enableDrag: false,
      builder: (ctx) {
        int pickedH = hour;
        int pickedM = minute;
        return StatefulBuilder(
          builder: (ctx, setSheetState) => SizedBox(
            height: 320,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Text(
                        isStart ? 'Начало охраны' : 'Конец охраны',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (isStart) {
                            setState(() {
                              _startHour = pickedH;
                              _startMinute = pickedM;
                            });
                          } else {
                            setState(() {
                              _endHour = pickedH;
                              _endMinute = pickedM;
                            });
                          }
                        },
                        child: const Text(
                          'Готово',
                          style: TextStyle(
                            color: Color(0xFF64D2FF),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    initialDateTime: DateTime(2000, 1, 1, hour, minute),
                    onDateTimeChanged: (dt) {
                      pickedH = dt.hour;
                      pickedM = dt.minute;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF17171B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final mutedColor = isDark ? const Color(0xFF6E6E75) : const Color(0xFF8E8E93);
    const guardColor = Color(0xFF64D2FF);

    // Вычисляем охватывает ли ночь
    final startMins = _startHour * 60 + _startMinute;
    final endMins = _endHour * 60 + _endMinute;
    final durationMins = startMins > endMins
        ? (24 * 60 - startMins + endMins)
        : (endMins - startMins);
    final durationH = durationMins ~/ 60;
    final durationM = durationMins % 60;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Время охраны',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Инфо
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: guardColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: guardColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_moon_outlined, color: guardColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'В указанный период при обнаружении движения придёт уведомление. Свет не включается.',
                    style: TextStyle(color: textColor, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Время начала
          _TimeCard(
            label: 'Начало',
            time: _fmt(_startHour, _startMinute),
            color: guardColor,
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () => _pickTime(
              isStart: true,
              hour: _startHour,
              minute: _startMinute,
            ),
          ),

          const SizedBox(height: 12),

          // Время конца
          _TimeCard(
            label: 'Конец',
            time: _fmt(_endHour, _endMinute),
            color: guardColor,
            cardBg: cardBg,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () => _pickTime(
              isStart: false,
              hour: _endHour,
              minute: _endMinute,
            ),
          ),

          const SizedBox(height: 20),

          // Итого
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_outlined, color: Color(0xFF64D2FF), size: 20),
                const SizedBox(width: 12),
                Text(
                  'Длительность:',
                  style: TextStyle(color: mutedColor, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  durationH > 0
                      ? '$durationH ч ${durationM > 0 ? '$durationM мин' : ''}'
                      : '$durationM мин',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          if (startMins == endMins)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'Начало и конец совпадают — режим не будет работать',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_saving || startMins == endMins) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: guardColor,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Сохранить',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String label;
  final String time;
  final Color color;
  final Color cardBg;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _TimeCard({
    required this.label,
    required this.time,
    required this.color,
    required this.cardBg,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: mutedColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              time,
              style: TextStyle(
                color: color,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: mutedColor, size: 20),
          ],
        ),
      ),
    );
  }
}
