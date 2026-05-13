import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';

const _zoneColors = <Color>[
  Color(0xFFFFD54F),
  Color(0xFF42A5F5),
  Color(0xFF4CAF50),
  Color(0xFF26C6DA),
  Color(0xFFAB47BC),
  Color(0xFFFF7043),
  Color(0xFFEC407A),
  Color(0xFFEF5350),
];

const _zoneEmojis = <String>[
  '💡',
  '🛋️',
  '🛏️',
  '🍳',
  '🚪',
  '🪴',
  '🛁',
  '🧸',
  '📚',
  '🎵',
];

class CreateZoneScreen extends StatefulWidget {
  final String deviceId;

  const CreateZoneScreen({super.key, required this.deviceId});

  @override
  State<CreateZoneScreen> createState() => _CreateZoneScreenState();
}

class _CreateZoneScreenState extends State<CreateZoneScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _name = TextEditingController();

  bool saving = false;
  bool loadingZones = true;
  String? error;
  int selectedColorIndex = 0;
  String selectedEmoji = _zoneEmojis.first;
  List<String> existingZoneNames = const <String>[];
  String? selectedExistingZone;

  @override
  void initState() {
    super.initState();
    _loadExistingZones();
  }

  String _prettyError(String raw) {
    if (raw.contains('404')) return 'Устройство не найдено';
    if (raw.contains('409') || raw.toLowerCase().contains('exists')) {
      return 'Такая зона уже существует';
    }
    return 'Не удалось добавить устройство';
  }

  Future<void> _loadExistingZones() async {
    try {
      final zones = await _api.getZones();
      final names =
          zones
              .map((zone) => (zone['name'] ?? '').toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (!mounted) return;
      setState(() {
        existingZoneNames = names;
      });
    } catch (_) {
      // Existing zones are optional here, screen still works with manual input.
    } finally {
      if (mounted) {
        setState(() => loadingZones = false);
      }
    }
  }

  Future<void> _submit() async {
    final zoneName = _name.text.trim();
    if (zoneName.isEmpty) {
      setState(() => error = 'Введите название зоны');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await _api.registerDevice(deviceId: widget.deviceId, zoneName: zoneName);
      if (!mounted) return;
      context.pop({
        'deviceId': widget.deviceId,
        'zoneName': zoneName,
        'emoji': selectedEmoji,
        'colorIndex': selectedColorIndex,
        'preserveExistingMeta': false,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = _prettyError(e.toString()));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final card = isDark ? const Color(0xFF171A1F) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF161A22);
    final muted = isDark ? const Color(0xFF858A95) : const Color(0xFF6D7481);
    final border = isDark ? const Color(0xFF262A32) : const Color(0xFFE2E6EF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Создать зону')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: _zoneColors[selectedColorIndex].withValues(
                        alpha: 0.18,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _zoneColors[selectedColorIndex].withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selectedEmoji,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Устройство: ${widget.deviceId}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: text),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Название зоны',
                    hintText: 'Например, Гостиная',
                  ),
                  onChanged: (_) {
                    final next = _name.text.trim();
                    setState(() {
                      error = null;
                      selectedExistingZone = existingZoneNames.contains(next)
                          ? next
                          : null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Или добавьте панель в уже существующую зону',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
                const SizedBox(height: 10),
                if (loadingZones)
                  const LinearProgressIndicator(minHeight: 2)
                else if (existingZoneNames.isEmpty)
                  Text(
                    'Пока нет созданных зон. Введите новое название выше.',
                    style: TextStyle(color: muted, fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: existingZoneNames.map((zoneName) {
                      final isSelected = selectedExistingZone == zoneName;
                      return ChoiceChip(
                        label: Text(zoneName),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            selectedExistingZone = zoneName;
                            _name.text = zoneName;
                            error = null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Смайлик зоны',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _zoneEmojis.map((emoji) {
                    final selected = emoji == selectedEmoji;
                    return GestureDetector(
                      onTap: () => setState(() => selectedEmoji = emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected
                              ? _zoneColors[selectedColorIndex].withValues(
                                  alpha: 0.16,
                                )
                              : (isDark
                                    ? const Color(0xFF10141B)
                                    : const Color(0xFFF2F4F8)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? _zoneColors[selectedColorIndex]
                                : border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Цвет зоны',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(_zoneColors.length, (index) {
                    final color = _zoneColors[index];
                    final selected = index == selectedColorIndex;
                    return GestureDetector(
                      onTap: () => setState(() => selectedColorIndex = index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? text : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Добавить',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'После сохранения зона сразу появится на главном экране.',
                    style: TextStyle(color: muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
