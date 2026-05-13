import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/api/mqtt_service.dart';

const _teal = Color(0xFF1ABFBF);

class ZoneScheduleScreen extends StatefulWidget {
  final String id;
  final String name;
  final String emoji;
  final bool isZone;
  final List<String> deviceIds;
  final bool autoEnable;

  const ZoneScheduleScreen({
    super.key,
    required this.id,
    required this.name,
    required this.emoji,
    required this.isZone,
    required this.deviceIds,
    this.autoEnable = false,
  });

  @override
  State<ZoneScheduleScreen> createState() => _ZoneScheduleScreenState();
}

class _ZoneScheduleScreenState extends State<ZoneScheduleScreen> {
  final ApiService _api = ApiService();

  bool _scheduleEnabled = false;
  List<_ScheduleRule> _rules = [];
  bool _loading = true;

  String get _prefsKey => 'schedule_${widget.id}';
  String get _enabledKey => 'schedule_enabled_${widget.id}';

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final rules = <_ScheduleRule>[];
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final item in list) {
          rules.add(_ScheduleRule.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _rules = rules;
        _scheduleEnabled = widget.autoEnable ? true : enabled;
        _loading = false;
      });
    }
  }

  Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    // Compute enabled from any active rule
    _scheduleEnabled = _rules.any((r) => r.enabled);
    await prefs.setString(
      _prefsKey,
      jsonEncode(_rules.map((r) => r.toJson()).toList()),
    );
    await prefs.setBool(_enabledKey, _scheduleEnabled);

    final targets = widget.isZone ? widget.deviceIds : [widget.id];

    // Send first rule to backend (legacy)
    if (_rules.isNotEmpty) {
      final rule = _rules.first;
      final onParts = rule.onTime.split(':');
      final offParts = rule.offTime.split(':');
      for (final deviceId in targets) {
        try {
          await _api.updateDeviceSchedule(
            deviceId,
            onHour: int.tryParse(onParts.first) ?? 0,
            onMinute: int.tryParse(onParts.last) ?? 0,
            offHour: int.tryParse(offParts.first) ?? 0,
            offMinute: int.tryParse(offParts.last) ?? 0,
          );
        } catch (_) {}
      }
    }

    // Send ALL rules to ESP32 directly via MQTT
    final mqtt = MqttService();
    final mqttPayload = jsonEncode(
      _rules.map((r) {
        final on = r.onTime.split(':');
        final off = r.offTime.split(':');
        return {
          'on_hour': int.tryParse(on.first) ?? 0,
          'on_minute': int.tryParse(on.last) ?? 0,
          'off_hour': int.tryParse(off.first) ?? 0,
          'off_minute': int.tryParse(off.last) ?? 0,
          'enabled': r.enabled,
        };
      }).toList(),
    );
    for (final deviceId in targets) {
      try {
        await mqtt.publish('home/$deviceId/schedule/set', mqttPayload);
      } catch (_) {}
    }
  }

  /// Returns the index of the conflicting rule, or -1
  int _conflictIndex(_ScheduleRule candidate, {int skipIndex = -1}) {
    for (int i = 0; i < _rules.length; i++) {
      if (i == skipIndex) continue;
      if (_rulesConflict(candidate, _rules[i])) return i;
    }
    return -1;
  }

  bool _rulesConflict(_ScheduleRule a, _ScheduleRule b) {
    final daysA = Set<int>.from(a.days);
    final daysB = Set<int>.from(b.days);
    // Empty days = every day → always overlaps
    final sharedDays = (daysA.isEmpty || daysB.isEmpty)
        ? true
        : daysA.intersection(daysB).isNotEmpty;
    if (!sharedDays) return false;
    return _timeOverlap(
      _toMin(a.onTime), _toMin(a.offTime),
      _toMin(b.onTime), _toMin(b.offTime),
    );
  }

  int _toMin(String t) {
    final parts = t.split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 + (int.tryParse(parts.last) ?? 0);
  }

  bool _timeOverlap(int on1, int off1, int on2, int off2) {
    // Handle midnight crossing
    if (off1 < on1) return _timeOverlap(on1, 1440, on2, off2) || _timeOverlap(0, off1, on2, off2);
    if (off2 < on2) return _timeOverlap(on1, off1, on2, 1440) || _timeOverlap(on1, off1, 0, off2);
    return on1 < off2 && on2 < off1;
  }

  Future<void> _addRule() async {
    final result = await showDialog<_ScheduleRule>(
      context: context,
      builder: (ctx) => const _RuleDialog(),
    );
    if (result == null || !mounted) return;
    final ci = _conflictIndex(result);
    if (ci != -1) {
      _showConflictWarning(_rules[ci]);
      return;
    }
    setState(() => _rules.add(result));
    await _saveRules();
  }

  Future<void> _editRule(int index) async {
    final result = await showDialog<_ScheduleRule>(
      context: context,
      builder: (ctx) => _RuleDialog(initial: _rules[index]),
    );
    if (result == null || !mounted) return;
    final ci = _conflictIndex(result, skipIndex: index);
    if (ci != -1) {
      _showConflictWarning(_rules[ci]);
      return;
    }
    setState(() => _rules[index] = result);
    await _saveRules();
  }

  void _showConflictWarning(_ScheduleRule conflicting) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF171A1F) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text('Конфликт времени',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
        content: Text(
          'Пересекается с расписанием\n${conflicting.onTime} → ${conflicting.offTime}.\n\nДва расписания не могут работать в одно время.',
          style: TextStyle(color: textColor.withValues(alpha: .75)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Понятно', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRule(int index, bool value) async {
    setState(() => _rules[index] = _rules[index].copyWith(enabled: value));
    await _saveRules();
  }

  Future<void> _deleteRule(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF171A1F) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF161A22);
        return AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Удалить расписание?', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
          content: Text(
            '${_rules[index].onTime} → ${_rules[index].offTime}',
            style: TextStyle(color: textColor.withValues(alpha: .7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Отмена', style: TextStyle(color: _teal)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    setState(() => _rules.removeAt(index));
    await _saveRules();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final card = isDark ? const Color(0xFF171A1F) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF6D7481);
    final border = isDark ? const Color(0xFF262A32) : const Color(0xFFE2E6EF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Управление по времени',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textColor),
            ),
            Row(
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(widget.name, style: TextStyle(fontSize: 13, color: mutedColor)),
              ],
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_rules.isEmpty) ...[
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        const Text('⏰', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text(
                          'Нет расписаний',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Нажмите «+», чтобы добавить расписание',
                          style: TextStyle(color: mutedColor, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ] else ...[
                  ...List.generate(_rules.length, (index) {
                    final rule = _rules[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RuleCard(
                        rule: rule,
                        card: card,
                        border: border,
                        textColor: textColor,
                        mutedColor: mutedColor,
                        isDark: isDark,
                        onToggle: (v) => _toggleRule(index, v),
                        onEdit: () => _editRule(index),
                        onDelete: () => _deleteRule(index),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addRule,
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text(
                      '+ Добавить расписание',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

}

// ── Rule card ──────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final _ScheduleRule rule;
  final Color card;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleCard({
    required this.rule,
    required this.card,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  static const _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final activeDays = rule.days.isEmpty
        ? 'Каждый день'
        : rule.days.map((d) => _dayNames[d]).join(', ');
    final dimmed = !rule.enabled;

    return AnimatedOpacity(
      opacity: dimmed ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: rule.enabled
                ? _teal.withValues(alpha: .5)
                : border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Per-rule toggle
            Switch(
              value: rule.enabled,
              onChanged: onToggle,
              activeThumbColor: Colors.black,
              activeTrackColor: _teal,
              inactiveThumbColor: isDark ? Colors.white54 : Colors.grey,
              inactiveTrackColor: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rule.onTime,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 16, color: mutedColor),
                        ),
                        Text(
                          rule.offTime,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeDays,
                      style: TextStyle(color: _teal, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            // Delete
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'Удалить',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rule dialog (добавление и редактирование) ─────────────────────────

class _RuleDialog extends StatefulWidget {
  final _ScheduleRule? initial; // null = новое, не-null = редактирование

  const _RuleDialog({this.initial});

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late TimeOfDay _onTime;
  late TimeOfDay _offTime;
  late Set<int> _selectedDays;

  static const _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      // Редактирование — заполняем из существующего
      final onParts = widget.initial!.onTime.split(':');
      final offParts = widget.initial!.offTime.split(':');
      _onTime = TimeOfDay(
        hour: int.tryParse(onParts.first) ?? 7,
        minute: int.tryParse(onParts.last) ?? 0,
      );
      _offTime = TimeOfDay(
        hour: int.tryParse(offParts.first) ?? 22,
        minute: int.tryParse(offParts.last) ?? 0,
      );
      _selectedDays = Set<int>.from(widget.initial!.days);
    } else {
      // Новое расписание
      _onTime = const TimeOfDay(hour: 7, minute: 0);
      _offTime = const TimeOfDay(hour: 22, minute: 0);
      _selectedDays = {0, 1, 2, 3, 4};
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isOn) async {
    final current = isOn ? _onTime : _offTime;
    DateTime temp = DateTime(2000, 1, 1, current.hour, current.minute);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF171A1F) : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF161A22);
        final mutedColor = isDark ? Colors.white60 : const Color(0xFF6D7481);

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    isOn ? '☀️' : '🌙',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isOn ? 'Включить в' : 'Выключить в',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: temp,
                  onDateTimeChanged: (dt) => temp = dt,
                  itemExtent: 48,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      final picked = TimeOfDay(hour: temp.hour, minute: temp.minute);
                      if (isOn) {
                        _onTime = picked;
                      } else {
                        _offTime = picked;
                      }
                    });
                    Navigator.of(ctx).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _teal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    'Готово',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: mutedColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF171A1F) : Colors.white;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF6D7481);
    final border = isDark ? const Color(0xFF262A32) : const Color(0xFFE2E6EF);

    final isEdit = widget.initial != null;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Редактировать расписание' : 'Новое расписание',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
            ),
            const SizedBox(height: 20),

            // Время вкл / выкл
            Row(
              children: [
                Expanded(child: _timePicker(
                  label: 'ВКЛЮЧИТЬ В',
                  time: _onTime,
                  onTap: () => _pickTime(true),
                  card: card,
                  border: border,
                  textColor: textColor,
                  mutedColor: mutedColor,
                )),
                const SizedBox(width: 12),
                Expanded(child: _timePicker(
                  label: 'ВЫКЛЮЧИТЬ В',
                  time: _offTime,
                  onTap: () => _pickTime(false),
                  card: card,
                  border: border,
                  textColor: textColor,
                  mutedColor: mutedColor,
                )),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              'ДНИ НЕДЕЛИ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: mutedColor, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (i) {
                final selected = _selectedDays.contains(i);
                return GestureDetector(
                  onTap: () => setState(() {
                    selected ? _selectedDays.remove(i) : _selectedDays.add(i);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? _teal : card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? _teal : border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _dayNames[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.black : mutedColor,
                      ),
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: border),
                      foregroundColor: textColor,
                    ),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _ScheduleRule(
                          id: widget.initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          onTime: _fmt(_onTime),
                          offTime: _fmt(_offTime),
                          days: _selectedDays.toList()..sort(),
                          enabled: widget.initial?.enabled ?? true,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      isEdit ? 'Сохранить' : 'Добавить',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePicker({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
    required Color card,
    required Color border,
    required Color textColor,
    required Color mutedColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: mutedColor, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor),
                ),
                Icon(Icons.access_time, color: _teal, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Model ──────────────────────────────────────────────────────────────

class _ScheduleRule {
  final String id;
  final String onTime;
  final String offTime;
  final List<int> days;
  final bool enabled;

  const _ScheduleRule({
    required this.id,
    required this.onTime,
    required this.offTime,
    required this.days,
    this.enabled = true,
  });

  _ScheduleRule copyWith({
    String? onTime,
    String? offTime,
    List<int>? days,
    bool? enabled,
  }) {
    return _ScheduleRule(
      id: id,
      onTime: onTime ?? this.onTime,
      offTime: offTime ?? this.offTime,
      days: days ?? this.days,
      enabled: enabled ?? this.enabled,
    );
  }

  factory _ScheduleRule.fromJson(Map<String, dynamic> json) {
    return _ScheduleRule(
      id: json['id']?.toString() ?? '',
      onTime: json['onTime']?.toString() ?? '07:00',
      offTime: json['offTime']?.toString() ?? '22:00',
      days: (json['days'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [],
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'onTime': onTime,
    'offTime': offTime,
    'days': days,
    'enabled': enabled,
  };
}
