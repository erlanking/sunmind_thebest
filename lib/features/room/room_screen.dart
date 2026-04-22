import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';
import 'package:sunmind_thebest/features/room/zone_schedule_screen.dart';

const _teal = Color(0xFF1ABFBF);

class RoomScreen extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic>? roomData;

  const RoomScreen({super.key, required this.roomId, this.roomData});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final ApiService _api = ApiService();

  bool _powerLoading = false;
  bool _brightnessLoading = false;
  bool _modeLoading = false;

  late bool isOn;
  late bool motionDetected;
  late bool isOnline;
  late double brightness;
  late int lux;
  late int battery;
  late bool isManualMode;

  late List<Map<String, dynamic>> _devices;
  final Map<String, bool> _deviceStates = {};
  final Set<String> _deviceLoading = {};

  String get itemKind => (widget.roomData?['kind'] ?? 'device').toString();
  bool get isZone => itemKind == 'zone';
  String get displayName => (widget.roomData?['name'] ?? 'Панель').toString();
  String get displayEmoji =>
      (widget.roomData?['emoji'] ?? (isZone ? '🏠' : '💡')).toString();

  List<String> get deviceIds =>
      (widget.roomData?['deviceIds'] as List?)
          ?.map((v) => v.toString())
          .where((v) => v.isNotEmpty)
          .toList() ??
      <String>[
        if ((widget.roomData?['deviceId'] ?? '').toString().isNotEmpty)
          (widget.roomData?['deviceId'] ?? '').toString(),
      ];

  int get panelCount {
    final raw = widget.roomData?['deviceCount'];
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? deviceIds.length;
    return deviceIds.length;
  }

  @override
  void initState() {
    super.initState();
    final data = widget.roomData ?? const <String, dynamic>{};
    isOn = data['on'] == true;
    motionDetected = data['motion'] == true;
    isOnline = data['online'] != false;
    brightness = (data['brightness'] as num?)?.toDouble() ?? 0;
    lux = (data['lux'] as num?)?.toInt() ?? 0;
    battery = (data['batteryPercent'] as num?)?.toInt() ?? 0;

    // Determine initial manual mode from devices
    final devices = (data['devices'] as List?)
            ?.whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList() ??
        const <Map<String, dynamic>>[];
    isManualMode = devices.isEmpty
        ? true
        : devices.any((d) {
            final raw = d['manual_mode'];
            if (raw is bool) return raw;
            if (raw is String) return raw.toLowerCase() == 'true';
            return true;
          });

    _devices = devices;
    for (final device in _devices) {
      final id = _deviceId(device);
      if (id.isNotEmpty) {
        _deviceStates[id] =
            device['led_state']?.toString().toUpperCase() == 'ON';
      }
    }
  }

  String _deviceId(Map<String, dynamic> device) =>
      (device['deviceId'] ?? device['id'] ?? '').toString().trim();

  bool _isManual(Map<String, dynamic> device) {
    final raw = device['manual_mode'];
    if (raw is bool) return raw;
    if (raw is String) return raw.toLowerCase() == 'true';
    return true;
  }

  // ── Power ─────────────────────────────────────────────────────────

  Future<void> _setPower(bool value) async {
    if (_powerLoading || deviceIds.isEmpty) return;
    HapticService.toggle();
    final previous = isOn;
    setState(() {
      _powerLoading = true;
      isOn = value;
    });
    try {
      final zoneId = widget.roomData?['zoneId']?.toString() ?? '';
      if (isZone && zoneId.isNotEmpty) {
        await _api.controlZone(zoneId, on: value);
      } else {
        await _api.setDevicesLed(deviceIds, value);
      }
      setState(() {
        for (final id in _deviceStates.keys) {
          _deviceStates[id] = value;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isOn = previous);
      _showError('Не удалось изменить питание: $e');
    } finally {
      if (mounted) setState(() => _powerLoading = false);
    }
  }

  // ── Brightness ────────────────────────────────────────────────────

  Future<void> _setBrightness(double value) async {
    if (_brightnessLoading) return;
    setState(() {
      brightness = value;
      _brightnessLoading = true;
    });
    try {
      for (final deviceId in deviceIds) {
        await _api.setDeviceBrightness(deviceId, value.round());
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _brightnessLoading = false);
    }
  }

  // ── Mode ──────────────────────────────────────────────────────────

  Future<void> _setMode(bool manual) async {
    if (_modeLoading) return;
    HapticService.medium();
    setState(() {
      _modeLoading = true;
      isManualMode = manual;
    });
    try {
      for (final deviceId in deviceIds) {
        await _api.setDeviceMode(deviceId, manual: manual);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isManualMode = !manual);
      _showError('Не удалось сменить режим: $e');
    } finally {
      if (mounted) setState(() => _modeLoading = false);
    }
  }

  // ── Individual device toggle ──────────────────────────────────────

  Future<void> _toggleDevice(String deviceId, bool currentOn) async {
    if (_deviceLoading.contains(deviceId)) return;
    HapticService.toggle();
    final next = !currentOn;
    setState(() {
      _deviceLoading.add(deviceId);
      _deviceStates[deviceId] = next;
    });
    try {
      await _api.setDeviceLed(deviceId, next);
      final anyOn = _deviceStates.values.any((on) => on);
      setState(() => isOn = anyOn);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deviceStates[deviceId] = currentOn);
      _showError('Не удалось управлять панелью: $e');
    } finally {
      if (mounted) setState(() => _deviceLoading.remove(deviceId));
    }
  }

  // ── Actions ───────────────────────────────────────────────────────

  void _openSchedule() {
    final zoneId = widget.roomData?['zoneId']?.toString() ?? '';
    final id = isZone && zoneId.isNotEmpty ? zoneId : deviceIds.first;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZoneScheduleScreen(
          id: id,
          name: displayName,
          emoji: displayEmoji,
          isZone: isZone,
          deviceIds: deviceIds,
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isZone ? 'Удалить зону?' : 'Удалить панель?'),
            content: Text(
              isZone
                  ? 'Зона исчезнет, а все панели останутся на главном экране как отдельные карточки.'
                  : 'Панель будет удалена только у текущего пользователя. На базе устройство останется.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;

    if (!mounted || !shouldDelete) return;
    Navigator.of(context).pop({
      'action': isZone ? 'deleteZone' : 'deleteDevice',
      if (isZone) 'zoneKey': widget.roomData?['zoneKey'],
      if (isZone) 'zoneId': widget.roomData?['zoneId'],
      if (isZone) 'deviceIds': deviceIds,
      if (!isZone) 'deviceId': widget.roomData?['deviceId'],
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── BUILD ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final panelColor = isDark ? const Color(0xFF171A1F) : Colors.white;
    final softPanel =
        isDark ? const Color(0xFF1A1E27) : const Color(0xFFF2F4F8);
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF6D7481);
    final borderColor =
        isDark ? const Color(0xFF262A32) : const Color(0xFFE2E6EF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '$displayEmoji $displayName',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        actions: [
          _SettingsMenu(
            onSchedule: _openSchedule,
            onDelete: _confirmDelete,
            textColor: textColor,
            isDark: isDark,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          children: [
            // ── Main power card ──
            _PowerCard(
              isOn: isOn,
              brightness: brightness,
              displayEmoji: displayEmoji,
              powerLoading: _powerLoading,
              onToggle: _setPower,
              textColor: textColor,
              mutedColor: mutedColor,
              panelColor: panelColor,
              motionDetected: motionDetected,
              isOnline: isOnline,
            ),

            const SizedBox(height: 16),

            // ── Brightness control ──
            _BrightnessCard(
              brightness: brightness,
              panelColor: panelColor,
              textColor: textColor,
              mutedColor: mutedColor,
              onChanged: (v) => setState(() => brightness = v),
              onChangeEnd: _setBrightness,
            ),

            const SizedBox(height: 16),

            // ── Mode card ──
            _ModeCard(
              isManual: isManualMode,
              modeLoading: _modeLoading,
              panelColor: panelColor,
              textColor: textColor,
              mutedColor: mutedColor,
              onChanged: _setMode,
            ),

            const SizedBox(height: 16),

            // ── Sensor info card ──
            _SensorCard(
              lux: lux,
              battery: battery,
              motionDetected: motionDetected,
              isOnline: isOnline,
              panelColor: panelColor,
              textColor: textColor,
              mutedColor: mutedColor,
            ),

            const SizedBox(height: 16),

            // ── Panels list (matryoshka) ──
            if (isZone && _devices.isNotEmpty)
              _PanelsGrid(
                devices: _devices,
                deviceStates: _deviceStates,
                deviceLoading: _deviceLoading,
                panelColor: panelColor,
                softPanel: softPanel,
                borderColor: borderColor,
                textColor: textColor,
                mutedColor: mutedColor,
                onToggleDevice: _toggleDevice,
                onOpenDevice: (deviceId) {
                  final device = _devices.firstWhere(
                    (d) => _deviceId(d) == deviceId,
                    orElse: () => {'deviceId': deviceId},
                  );
                  context.push('/room/$deviceId', extra: {
                    'kind': 'device',
                    'deviceId': deviceId,
                    'deviceIds': [deviceId],
                    'deviceCount': 1,
                    'name': (device['name'] ?? deviceId).toString(),
                    'emoji': '💡',
                    'on': _deviceStates[deviceId] ?? false,
                    'motion': device['motion_active'] ?? false,
                    'online': device['connected'] != false,
                    'brightness': device['brightness'] ?? 0,
                    'batteryPercent':
                        device['batteryPercent'] ?? device['battery'] ?? 0,
                    'lux': device['lux'] ?? 0,
                    'manual_mode': _isManual(device),
                    'devices': [device],
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ── Settings popup menu ────────────────────────────────────────────────

class _SettingsMenu extends StatelessWidget {
  final VoidCallback onSchedule;
  final VoidCallback onDelete;
  final Color textColor;
  final bool isDark;

  const _SettingsMenu({
    required this.onSchedule,
    required this.onDelete,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2229) : const Color(0xFFF2F4F8),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.settings_outlined, color: textColor, size: 20),
      ),
      color: isDark ? const Color(0xFF1E2229) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'schedule') onSchedule();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'schedule',
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Text('⏰', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Text(
                'По времени',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF161A22),
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Удалить зону',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Power card ─────────────────────────────────────────────────────────

class _PowerCard extends StatelessWidget {
  final bool isOn;
  final double brightness;
  final String displayEmoji;
  final bool powerLoading;
  final ValueChanged<bool> onToggle;
  final Color textColor;
  final Color mutedColor;
  final Color panelColor;
  final bool motionDetected;
  final bool isOnline;

  const _PowerCard({
    required this.isOn,
    required this.brightness,
    required this.displayEmoji,
    required this.powerLoading,
    required this.onToggle,
    required this.textColor,
    required this.mutedColor,
    required this.panelColor,
    required this.motionDetected,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Big sun icon with glow
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn
                  ? const Color(0xFFF7931A).withValues(alpha: .15)
                  : Colors.white10,
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF7931A).withValues(alpha: .3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ]
                  : [],
              border: Border.all(
                color: isOn
                    ? const Color(0xFFF7931A).withValues(alpha: .6)
                    : Colors.white12,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              isOn ? '☀️' : '🌙',
              style: const TextStyle(fontSize: 48),
            ),
          ),

          const SizedBox(height: 16),

          // Brightness % and toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${brightness.round()}%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: isOn,
                onChanged: powerLoading ? null : onToggle,
                activeThumbColor: _teal,
                activeTrackColor: _teal.withValues(alpha: .4),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Status dots
          Wrap(
            spacing: 10,
            children: [
              _StatusDot(
                active: motionDetected,
                label: motionDetected ? 'Движение' : 'Нет движения',
                color: motionDetected ? Colors.greenAccent : mutedColor,
              ),
              _StatusDot(
                active: isOnline,
                label: isOnline ? 'Онлайн' : 'Офлайн',
                color: isOnline ? Colors.greenAccent : Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Brightness card ────────────────────────────────────────────────────

class _BrightnessCard extends StatelessWidget {
  final double brightness;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _BrightnessCard({
    required this.brightness,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
    required this.onChanged,
    required this.onChangeEnd,
  });

  static const _presets = [
    _BrightnessPreset('🌑', 15),
    _BrightnessPreset('🌒', 40),
    _BrightnessPreset('🌓', 70),
    _BrightnessPreset('🌕', 100),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Яркость',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Text(
                '${brightness.round()}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _teal,
              inactiveTrackColor: _teal.withValues(alpha: .2),
              thumbColor: _teal,
              overlayColor: _teal.withValues(alpha: .1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: brightness.clamp(0, 100),
              min: 0,
              max: 100,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),

          const SizedBox(height: 12),

          // Preset buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _presets.map((preset) {
              final selected =
                  (brightness - preset.value).abs() < 5 &&
                  brightness > 0;
              return GestureDetector(
                onTap: () {
                  onChanged(preset.value.toDouble());
                  onChangeEnd(preset.value.toDouble());
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56,
                  height: 48,
                  decoration: BoxDecoration(
                    color: selected
                        ? _teal.withValues(alpha: .15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? _teal.withValues(alpha: .6)
                          : Colors.white12,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    preset.emoji,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BrightnessPreset {
  final String emoji;
  final int value;
  const _BrightnessPreset(this.emoji, this.value);
}

// ── Mode card ──────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final bool isManual;
  final bool modeLoading;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<bool> onChanged;

  const _ModeCard({
    required this.isManual,
    required this.modeLoading,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'РЕЖИМ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: mutedColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  label: 'Авто',
                  emoji: '🤖',
                  selected: !isManual,
                  loading: modeLoading && isManual,
                  onTap: () => onChanged(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeButton(
                  label: 'Ручной',
                  emoji: '✋',
                  selected: isManual,
                  loading: modeLoading && !isManual,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _teal.withValues(alpha: .12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _teal : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _teal,
                ),
              )
            : Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? _teal : Colors.white60,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Panels grid (matryoshka) ───────────────────────────────────────────

class _PanelsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> devices;
  final Map<String, bool> deviceStates;
  final Set<String> deviceLoading;
  final Color panelColor;
  final Color softPanel;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final void Function(String deviceId, bool currentOn) onToggleDevice;
  final void Function(String deviceId) onOpenDevice;

  const _PanelsGrid({
    required this.devices,
    required this.deviceStates,
    required this.deviceLoading,
    required this.panelColor,
    required this.softPanel,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onToggleDevice,
    required this.onOpenDevice,
  });

  String _id(Map<String, dynamic> d) =>
      (d['deviceId'] ?? d['id'] ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                'Панели в зоне',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _teal.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _teal.withValues(alpha: .4)),
                ),
                child: Text(
                  '${devices.length} шт.',
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: devices.map((device) {
            final id = _id(device);
            final isOn = deviceStates[id] ?? false;
            final isLoading = deviceLoading.contains(id);
            final name = (device['name'] ?? device['deviceId'] ?? 'Панель')
                .toString();
            final brightness =
                (device['brightness'] as num?)?.toInt() ?? 0;
            final battery =
                (device['batteryPercent'] ?? device['battery'] as num?)
                    ?.toInt() ??
                0;
            final motion = device['motion_active'] == true;
            final online = device['connected'] != false;

            return _PanelCard(
              deviceId: id,
              name: name,
              isOn: isOn,
              isLoading: isLoading,
              brightness: brightness,
              battery: battery,
              motion: motion,
              online: online,
              panelColor: panelColor,
              softPanel: softPanel,
              borderColor: borderColor,
              textColor: textColor,
              mutedColor: mutedColor,
              onToggle: () => onToggleDevice(id, isOn),
              onTap: () => onOpenDevice(id),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Individual panel card (matryoshka style) ───────────────────────────

class _PanelCard extends StatelessWidget {
  final String deviceId;
  final String name;
  final bool isOn;
  final bool isLoading;
  final int brightness;
  final int battery;
  final bool motion;
  final bool online;
  final Color panelColor;
  final Color softPanel;
  final Color borderColor;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const _PanelCard({
    required this.deviceId,
    required this.name,
    required this.isOn,
    required this.isLoading,
    required this.brightness,
    required this.battery,
    required this.motion,
    required this.online,
    required this.panelColor,
    required this.softPanel,
    required this.borderColor,
    required this.textColor,
    required this.mutedColor,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = _teal;
    final activeBg = isOn
        ? LinearGradient(
            colors: [
              _teal.withValues(alpha: .18),
              _teal.withValues(alpha: .05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panelColor,
          gradient: activeBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isOn ? activeColor.withValues(alpha: .45) : borderColor,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isOn
                        ? activeColor.withValues(alpha: .22)
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('💡', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _teal,
                        ),
                      )
                    : GestureDetector(
                        onTap: onToggle,
                        child: _MiniToggle(value: isOn),
                      ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Отдельная панель',
              style: TextStyle(
                color: isOn ? activeColor : mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$brightness%  •  Бат. $battery%',
              style: TextStyle(
                color: mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _StatusDot(
                  active: motion,
                  label: motion ? 'Движение' : 'Нет движ.',
                  color: motion ? Colors.greenAccent : mutedColor,
                  small: true,
                ),
                _StatusDot(
                  active: online,
                  label: online ? 'Online' : 'Offline',
                  color: online ? Colors.greenAccent : Colors.redAccent,
                  small: true,
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ── Mini toggle ───────────────────────────────────────────────────────

class _MiniToggle extends StatelessWidget {
  final bool value;
  const _MiniToggle({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 38,
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: value ? _teal : Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: value ? Colors.black : Colors.white70,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

// ── Sensor info card ───────────────────────────────────────────────────

class _SensorCard extends StatelessWidget {
  final int lux;
  final int battery;
  final bool motionDetected;
  final bool isOnline;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;

  const _SensorCard({
    required this.lux,
    required this.battery,
    required this.motionDetected,
    required this.isOnline,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _Row(
            icon: Icons.wb_sunny_outlined,
            iconColor: const Color(0xFFF7931A),
            title: 'Освещённость',
            value: '$lux lux',
            valueColor: const Color(0xFFF7931A),
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 14),
          _Row(
            icon: Icons.battery_charging_full_rounded,
            iconColor: battery < 20 ? Colors.redAccent : Colors.green,
            title: 'Заряд батареи',
            value: '$battery%',
            valueColor: battery < 20 ? Colors.redAccent : Colors.green,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 14),
          _Row(
            icon: Icons.motion_photos_on_outlined,
            iconColor: motionDetected ? Colors.green : mutedColor,
            title: 'Движение',
            value: motionDetected ? 'Обнаружено' : 'Нет',
            valueColor: motionDetected ? Colors.green : mutedColor,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 14),
          _Row(
            icon: Icons.wifi_rounded,
            iconColor: isOnline ? Colors.green : Colors.redAccent,
            title: 'Статус',
            value: isOnline ? 'Online' : 'Offline',
            valueColor: isOnline ? Colors.green : Colors.redAccent,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final Color valueColor;
  final Color textColor;
  final Color mutedColor;

  const _Row({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 15, color: textColor),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ── Status dot ────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final bool active;
  final String label;
  final Color color;
  final bool small;

  const _StatusDot({
    required this.active,
    required this.label,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: .15)
            : (isDark ? Colors.white10 : const Color(0xFFF2F4F8)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? color.withValues(alpha: .5)
              : (isDark
                    ? const Color(0xFF262A32)
                    : const Color(0xFFE2E6EF)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: active ? color : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: small ? 3 : 4),
          Text(
            label,
            style: TextStyle(
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: active
                  ? (isDark ? Colors.white : const Color(0xFF161A22))
                  : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
