import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';

const _teal = Color(0xFF1ABFBF);

class ZoneScheduleScreen extends StatefulWidget {
  final String id; // zoneId or deviceId
  final String name;
  final String emoji;
  final bool isZone;
  final List<String> deviceIds;

  const ZoneScheduleScreen({
    super.key,
    required this.id,
    required this.name,
    required this.emoji,
    required this.isZone,
    required this.deviceIds,
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
        _scheduleEnabled = enabled;
        _loading = false;
      });
    }
  }

  Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_rules.map((r) => r.toJson()).toList()),
    );
    await prefs.setBool(_enabledKey, _scheduleEnabled);

    // Sync first rule to backend if schedule is enabled
    if (_scheduleEnabled && _rules.isNotEmpty) {
      final rule = _rules.first;
      final onParts = rule.onTime.split(':');
      final offParts = rule.offTime.split(':');
      final targets = widget.isZone ? widget.deviceIds : [widget.id];
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
  }

  Future<void> _addRule() async {
    final result = await showDialog<_ScheduleRule>(
      context: context,
      builder: (ctx) => const _AddRuleDialog(),
    );
    if (result == null || !mounted) return;
    setState(() => _rules.add(result));
    await _saveRules();
  }

  Future<void> _deleteRule(int index) async {
    setState(() => _rules.removeAt(index));
    await _saveRules();
  }

  Future<void> _toggleSchedule(bool value) async {
    setState(() => _scheduleEnabled = value);
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
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            Row(
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  widget.name,
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
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
                // Enable schedule toggle
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _scheduleEnabled
                            ? _teal.withValues(alpha: .2)
                            : (isDark
                                  ? Colors.white12
                                  : const Color(0xFFF2F4F8)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('⏰', style: TextStyle(fontSize: 20)),
                    ),
                    title: Text(
                      'Включить расписание',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    subtitle: Text(
                      '${_rules.length} расписание',
                      style: TextStyle(color: mutedColor, fontSize: 13),
                    ),
                    value: _scheduleEnabled,
                    onChanged: _toggleSchedule,
                    activeThumbColor: _teal,
                    activeTrackColor: _teal.withValues(alpha: .4),
                  ),
                ),

                const SizedBox(height: 24),

                if (_rules.isEmpty) ...[
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        const Text('⏰', style: TextStyle(fontSize: 64)),
                        const SizedBox(height: 16),
                        Text(
                          'Нет правил',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Нажмите «+», чтобы добавить расписание включения',
                          style: TextStyle(color: mutedColor, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
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
                        onDelete: () => _deleteRule(index),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // Add rule button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addRule,
                    icon: const Icon(Icons.add, color: Colors.black),
                    label: const Text(
                      '+ Добавить правило',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Rule card ─────────────────────────────────────────────────────────

class _RuleCard extends StatelessWidget {
  final _ScheduleRule rule;
  final Color card;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onDelete;

  const _RuleCard({
    required this.rule,
    required this.card,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.onDelete,
  });

  static const _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final activeDays = rule.days.map((d) => _dayNames[d]).join(', ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rule.onTime,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: mutedColor,
                      ),
                    ),
                    Text(
                      rule.offTime,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  activeDays.isEmpty ? 'Каждый день' : activeDays,
                  style: TextStyle(color: mutedColor, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}

// ── Add rule dialog ────────────────────────────────────────────────────

class _AddRuleDialog extends StatefulWidget {
  const _AddRuleDialog();

  @override
  State<_AddRuleDialog> createState() => _AddRuleDialogState();
}

class _AddRuleDialogState extends State<_AddRuleDialog> {
  TimeOfDay _onTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _offTime = const TimeOfDay(hour: 22, minute: 0);
  final Set<int> _selectedDays = {0, 1, 2, 3, 4}; // Mon-Fri by default

  static const _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickOnTime() async {
    final picked = await showTimePicker(context: context, initialTime: _onTime);
    if (picked != null) setState(() => _onTime = picked);
  }

  Future<void> _pickOffTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _offTime);
    if (picked != null) setState(() => _offTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF171A1F) : Colors.white;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF6D7481);
    final border = isDark ? const Color(0xFF262A32) : const Color(0xFFE2E6EF);

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
              'Новое правило',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),

            // On/Off time row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ВКЛЮЧИТЬ В',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: mutedColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickOnTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Text(
                            _formatTime(_onTime),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ВЫКЛЮЧИТЬ В',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: mutedColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickOffTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Text(
                            _formatTime(_offTime),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Text(
              'ДНИ НЕДЕЛИ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: mutedColor,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: List.generate(7, (i) {
                final selected = _selectedDays.contains(i);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedDays.remove(i);
                    } else {
                      _selectedDays.add(i);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selected ? _teal : card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _teal : border,
                      ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          onTime: _formatTime(_onTime),
                          offTime: _formatTime(_offTime),
                          days: _selectedDays.toList()..sort(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Добавить',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
}

// ── Model ──────────────────────────────────────────────────────────────

class _ScheduleRule {
  final String id;
  final String onTime;
  final String offTime;
  final List<int> days;

  const _ScheduleRule({
    required this.id,
    required this.onTime,
    required this.offTime,
    required this.days,
  });

  factory _ScheduleRule.fromJson(Map<String, dynamic> json) {
    return _ScheduleRule(
      id: json['id']?.toString() ?? '',
      onTime: json['onTime']?.toString() ?? '07:00',
      offTime: json['offTime']?.toString() ?? '22:00',
      days: (json['days'] as List?)?.map((e) => (e as num).toInt()).toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'onTime': onTime,
        'offTime': offTime,
        'days': days,
      };
}
