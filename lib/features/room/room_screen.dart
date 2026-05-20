import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';
import 'package:sunmind_thebest/features/device/night_guard_schedule_screen.dart';
import 'package:sunmind_thebest/features/room/zone_schedule_screen.dart';

const _teal = Color(0xFF1ABFBF);
const _kA1 = Color(0xFFFFD54F);
const _kA2 = Color(0xFFFF9F43);
const _kA3 = Color(0xFFFF6B35);

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
  bool _moveLoading = false;
  bool _membershipChanged = false;
  bool _nightGuardLoading = false;
  bool _nightGuardEnabled = false;
  bool _powerSourceLoading = false;
  String _powerSource = 'battery'; // 'battery' | 'ac'
  bool _chargingLoading = false;
  bool _isCharging = false;
  int _nightGuardStartHour = 22;
  int _nightGuardStartMinute = 0;
  int _nightGuardEndHour = 6;
  int _nightGuardEndMinute = 0;

  late bool isOn;
  late bool motionDetected;
  late bool isOnline;
  late double brightness;
  late int lux;
  late int battery;
  late double temperature;
  late double humidity;
  late String deviceMode; // "manual" | "auto" | "schedule"

  late List<Map<String, dynamic>> _devices;
  final Map<String, bool> _deviceStates = {};
  final Set<String> _deviceLoading = {};

  String get itemKind => (widget.roomData?['kind'] ?? 'device').toString();
  bool get isZone => itemKind == 'zone';
  String get displayName => (widget.roomData?['name'] ?? 'device.panel'.tr()).toString();
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
    brightness = _normBrightness((data['brightness'] as num?)?.toDouble() ?? 0);
    lux = (data['lux'] as num?)?.toInt() ?? 0;
    battery = (data['batteryPercent'] as num?)?.toInt() ?? 0;
    temperature = (data['temperature'] as num?)?.toDouble() ?? 0;
    humidity = (data['humidity'] as num?)?.toDouble() ?? 0;

    // Determine initial mode from devices
    final devices =
        (data['devices'] as List?)
            ?.whereType<Map>()
            .map((raw) => Map<String, dynamic>.from(raw))
            .toList() ??
        const <Map<String, dynamic>>[];
    deviceMode = _resolveMode(devices.isEmpty ? null : devices.first);

    _devices = devices;
    for (final device in _devices) {
      final id = _deviceId(device);
      if (id.isNotEmpty) {
        _deviceStates[id] =
            device['led_state']?.toString().toUpperCase() == 'ON';
      }
    }
    _powerSource = (data['powerSource'] as String?)?.toLowerCase() == 'ac' ? 'ac' : 'battery';
    _isCharging = data['isCharging'] == true;
    _nightGuardEnabled = data['nightGuardEnabled'] == true;
    _nightGuardStartHour = (data['nightGuardStartHour'] as num?)?.toInt() ?? 22;
    _nightGuardStartMinute = (data['nightGuardStartMinute'] as num?)?.toInt() ?? 0;
    _nightGuardEndHour = (data['nightGuardEndHour'] as num?)?.toInt() ?? 6;
    _nightGuardEndMinute = (data['nightGuardEndMinute'] as num?)?.toInt() ?? 0;

    // Подгружаем актуальное расписание с бэкенда (roomData может быть устаревшим)
    if (deviceIds.isNotEmpty) {
      Future.microtask(() => _fetchNightGuardSchedule());
    }
  }

  Future<void> _fetchNightGuardSchedule() async {
    try {
      final status = await _api.getDeviceStatus(deviceIds.first);
      if (!mounted) return;
      setState(() {
        _nightGuardEnabled = status['nightGuardEnabled'] == true;
        _nightGuardStartHour = (status['nightGuardStartHour'] as num?)?.toInt() ?? _nightGuardStartHour;
        _nightGuardStartMinute = (status['nightGuardStartMinute'] as num?)?.toInt() ?? _nightGuardStartMinute;
        _nightGuardEndHour = (status['nightGuardEndHour'] as num?)?.toInt() ?? _nightGuardEndHour;
        _nightGuardEndMinute = (status['nightGuardEndMinute'] as num?)?.toInt() ?? _nightGuardEndMinute;
        final ps = (status['powerSource'] as String?)?.toLowerCase();
        if (ps == 'ac' || ps == 'battery') _powerSource = ps!;
        _isCharging = status['isCharging'] == true;
      });
    } catch (_) {
      // Молча игнорируем — используем данные из roomData
    }
  }

  String _deviceId(Map<String, dynamic> device) =>
      (device['deviceId'] ?? device['id'] ?? '').toString().trim();

  /// Converts 0-255 PWM brightness to 0-100 percent
  static double _normBrightness(double raw) =>
      raw > 100 ? (raw / 255 * 100).clamp(0, 100) : raw.clamp(0, 100);


  /// Возвращает "manual" | "auto" | "schedule" из любого формата поля
  String _resolveMode(Map<String, dynamic>? device) {
    if (device == null) return 'manual';
    final m = device['mode'];
    if (m is String && m.isNotEmpty) return m;
    final mm = device['manual_mode'] ?? device['manualMode'];
    if (mm == true) return 'manual';
    if (mm == false) return 'auto';
    return 'manual';
  }

  bool _isManual(Map<String, dynamic>? device) {
    return _resolveMode(device) == 'manual';
  }

  String get _currentZoneId => (widget.roomData?['zoneId'] ?? '').toString();

  void _recomputeFromDevices() {
    final brightnessValues = _devices
        .map((device) => _normBrightness((device['brightness'] as num?)?.toDouble() ?? 0))
        .where((value) => value > 0)
        .toList();
    final batteryValues = _devices
        .map(
          (device) => (device['batteryPercent'] ?? device['battery'] as num?),
        )
        .whereType<num>()
        .map((value) => value.toInt())
        .where((value) => value > 0)
        .toList();
    final luxValues = _devices
        .map((device) => (device['lux'] as num?)?.toInt() ?? 0)
        .where((value) => value > 0)
        .toList();
    final temperatureValues = _devices
        .map((device) => (device['temperature'] as num?)?.toDouble() ?? 0)
        .where((value) => value > 0)
        .toList();
    final humidityValues = _devices
        .map((device) => (device['humidity'] as num?)?.toDouble() ?? 0)
        .where((value) => value > 0)
        .toList();

    isOn = _deviceStates.values.any((state) => state);
    motionDetected = _devices.any((device) => device['motion_active'] == true);
    isOnline =
        _devices.isNotEmpty && _devices.every((d) => d['connected'] != false);
    brightness = brightnessValues.isEmpty
        ? 0
        : brightnessValues.reduce((a, b) => a + b) / brightnessValues.length;
    battery = batteryValues.isEmpty
        ? 0
        : batteryValues.reduce((a, b) => a < b ? a : b);
    lux = luxValues.isEmpty
        ? 0
        : (luxValues.reduce((a, b) => a + b) / luxValues.length).round();
    temperature = temperatureValues.isEmpty
        ? 0
        : temperatureValues.reduce((a, b) => a + b) / temperatureValues.length;
    humidity = humidityValues.isEmpty
        ? 0
        : humidityValues.reduce((a, b) => a + b) / humidityValues.length;
    deviceMode = _resolveMode(_devices.isEmpty ? null : _devices.first);
  }

  void _removeDeviceLocally(String deviceId) {
    _devices.removeWhere((device) => _deviceId(device) == deviceId);
    _deviceStates.remove(deviceId);
    _membershipChanged = true;
    _recomputeFromDevices();
  }

  Future<void> _moveDeviceOutsideZone(_RoomDraggedPanel payload) async {
    if (_moveLoading) return;
    final deviceId = payload.deviceId.trim();
    if (deviceId.isEmpty || _currentZoneId.isEmpty) {
      _showError('errors.zone_not_found'.tr());
      return;
    }

    setState(() => _moveLoading = true);
    try {
      await _api.removeDeviceFromZone(_currentZoneId, deviceId);
      if (!mounted) return;
      setState(() => _removeDeviceLocally(deviceId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('zone.panel_moved_out'.tr())));
      HapticService.success();
    } catch (e) {
      if (!mounted) return;
      _showError(
        ApiService.isOfflineError(e)
            ? 'errors.internet'.tr()
            : 'errors.move_panel'.tr(),
      );
    } finally {
      if (mounted) setState(() => _moveLoading = false);
    }
  }

  Future<String?> _promptNewZoneName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('zone.new_zone'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'zone.zone_name'.tr(),
            hintText: 'zone.zone_name_example'.tr(),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('common.create'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<String?> _showDevicePicker() async {
    if (_devices.length == 1) return _deviceId(_devices.first);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('zone.select_panel'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _devices.map((d) {
            final id = _deviceId(d);
            final name = (d['name'] ?? id).toString();
            return ListTile(
              leading: const Text('💡'),
              title: Text(name),
              onTap: () => Navigator.of(ctx).pop(id),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTapOutside() async {
    if (_devices.isEmpty) return;
    final deviceId = await _showDevicePicker();
    if (deviceId == null || deviceId.isEmpty) return;
    final device = _devices.firstWhere(
      (d) => _deviceId(d) == deviceId,
      orElse: () => {'deviceId': deviceId},
    );
    final name = (device['name'] ?? deviceId).toString();
    await _moveDeviceOutsideZone(_RoomDraggedPanel(deviceId: deviceId, name: name));
  }

  Future<void> _handleTapNewZone() async {
    if (_devices.isEmpty) return;
    final deviceId = await _showDevicePicker();
    if (deviceId == null || deviceId.isEmpty) return;
    final device = _devices.firstWhere(
      (d) => _deviceId(d) == deviceId,
      orElse: () => {'deviceId': deviceId},
    );
    final name = (device['name'] ?? deviceId).toString();
    await _moveDeviceToNewZone(_RoomDraggedPanel(deviceId: deviceId, name: name));
  }

  Future<void> _moveDeviceToNewZone(_RoomDraggedPanel payload) async {
    if (_moveLoading) return;
    final deviceId = payload.deviceId.trim();
    if (deviceId.isEmpty) return;

    final zoneName = await _promptNewZoneName();
    if (zoneName == null || zoneName.isEmpty) return;

    setState(() => _moveLoading = true);
    try {
      final zone = await _api.createZone(name: zoneName);
      final zoneId = (zone['id'] ?? '').toString().trim();
      if (zoneId.isEmpty) {
        throw Exception('Zone id missing');
      }
      await _api.addDevicesToZone(zoneId, deviceIds: [deviceId]);
      if (!mounted) return;
      setState(() => _removeDeviceLocally(deviceId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('zone.zone_created_success'.tr(namedArgs: {'zone': zoneName}))));
      HapticService.success();
    } catch (e) {
      if (!mounted) return;
      _showError(
        ApiService.isOfflineError(e)
            ? 'errors.internet'.tr()
            : 'errors.create_zone'.tr(),
      );
    } finally {
      if (mounted) setState(() => _moveLoading = false);
    }
  }

  void _closeScreen() {
    Navigator.of(
      context,
    ).pop(_membershipChanged ? {'action': 'refresh'} : null);
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
      _showError(
        ApiService.isOfflineError(e)
            ? 'errors.internet'.tr()
            : 'errors.device_offline'.tr(),
      );
    } finally {
      if (mounted) setState(() => _powerLoading = false);
    }
  }

  // ── Brightness ────────────────────────────────────────────────────

  Future<void> _setBrightness(double value) async {
    if (_brightnessLoading || !isOn) return;
    setState(() {
      brightness = value;
      _brightnessLoading = true;
    });
    try {
      for (final deviceId in deviceIds) {
        // ESP32 expects 0-255; slider value is 0-100
        await _api.setDeviceBrightness(deviceId, (value / 100 * 255).round());
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _brightnessLoading = false);
    }
  }

  // ── Mode ──────────────────────────────────────────────────────────

  Future<void> _setMode(String mode) async {
    if (_modeLoading) return;
    HapticService.medium();
    final previous = deviceMode;
    setState(() {
      _modeLoading = true;
      deviceMode = mode;
    });
    try {
      for (final deviceId in deviceIds) {
        await _api.setDeviceMode(deviceId, mode: mode);
      }
      if (mounted && mode == 'schedule') _openSchedule(autoEnable: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => deviceMode = previous);
      _showError(
        ApiService.isOfflineError(e)
            ? 'errors.internet'.tr()
            : 'errors.change_mode'.tr(),
      );
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
      _showError(
        ApiService.isOfflineError(e)
            ? 'errors.internet'.tr()
            : 'errors.device_offline'.tr(),
      );
    } finally {
      if (mounted) setState(() => _deviceLoading.remove(deviceId));
    }
  }

  Future<void> _toggleNightGuard(bool value) async {
    if (_nightGuardLoading) return;
    setState(() => _nightGuardLoading = true);
    try {
      final firstId = deviceIds.isEmpty ? '' : deviceIds.first;
      if (firstId.isEmpty) return;
      await _api.setNightGuard(firstId, enabled: value);
      if (mounted) setState(() => _nightGuardEnabled = value);
      HapticService.success();
    } catch (e) {
      if (mounted) {
        _showError(
          ApiService.isOfflineError(e)
              ? 'errors.internet_short'.tr()
              : 'errors.night_guard'.tr(),
        );
      }
    } finally {
      if (mounted) setState(() => _nightGuardLoading = false);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────

  void _openSchedule({bool autoEnable = false}) {
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
          autoEnable: autoEnable,
        ),
      ),
    );
  }

  Future<void> _openNightGuardSchedule() async {
    if (deviceIds.isEmpty) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NightGuardScheduleScreen(
          deviceId: deviceIds.first,
          deviceName: displayName,
          initialStartHour: _nightGuardStartHour,
          initialStartMinute: _nightGuardStartMinute,
          initialEndHour: _nightGuardEndHour,
          initialEndMinute: _nightGuardEndMinute,
        ),
      ),
    );
    if (result == true && mounted) {
      // Reload device status to get updated schedule times
      try {
        final status = await _api.getDeviceStatus(deviceIds.first);
        if (mounted) {
          setState(() {
            _nightGuardEnabled = status['nightGuardEnabled'] == true;
            _nightGuardStartHour = (status['nightGuardStartHour'] as num?)?.toInt() ?? _nightGuardStartHour;
            _nightGuardStartMinute = (status['nightGuardStartMinute'] as num?)?.toInt() ?? _nightGuardStartMinute;
            _nightGuardEndHour = (status['nightGuardEndHour'] as num?)?.toInt() ?? _nightGuardEndHour;
            _nightGuardEndMinute = (status['nightGuardEndMinute'] as num?)?.toInt() ?? _nightGuardEndMinute;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _nightGuardEnabled = true);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isZone ? 'zone.delete_zone_confirm'.tr() : 'zone.delete_device_confirm'.tr()),
            content: Text(
              isZone
                  ? 'zone.delete_zone_hint'.tr()
                  : 'zone.delete_device_hint'.tr(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('common.cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('common.delete'.tr()),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── BUILD ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final panelColor = isDark ? const Color(0xFF171A1F) : Colors.white;
    final softPanel = isDark
        ? const Color(0xFF1A1E27)
        : const Color(0xFFF2F4F8);
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF6D7481);
    final borderColor = isDark
        ? const Color(0xFF262A32)
        : const Color(0xFFE2E6EF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: _closeScreen,
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
            onDelete: _confirmDelete,
            textColor: textColor,
            isDark: isDark,
            isZone: isZone,
          ),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _closeScreen();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                isOn: isOn,
                panelColor: panelColor,
                textColor: textColor,
                mutedColor: mutedColor,
                onChanged: (v) => setState(() => brightness = v),
                onChangeEnd: _setBrightness,
              ),

              const SizedBox(height: 16),

              // ── Mode card ──
              _ModeCard(
                deviceMode: deviceMode,
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
                temperature: temperature,
                humidity: humidity,
                motionDetected: motionDetected,
                isOnline: isOnline,
                panelColor: panelColor,
                textColor: textColor,
                mutedColor: mutedColor,
              ),

              const SizedBox(height: 16),

              // ── Night guard card ──
              if (!isZone)
                _NightGuardCard(
                  enabled: _nightGuardEnabled,
                  loading: _nightGuardLoading,
                  startHour: _nightGuardStartHour,
                  startMinute: _nightGuardStartMinute,
                  endHour: _nightGuardEndHour,
                  endMinute: _nightGuardEndMinute,
                  panelColor: panelColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  onChanged: _toggleNightGuard,
                  onSchedule: _openNightGuardSchedule,
                ),

              if (!isZone) const SizedBox(height: 16),

              // ── Quick actions: diagnostics / errors / maintenance ──
              if (!isZone)
                _DeviceActionsCard(
                  deviceId: deviceIds.isEmpty ? '' : deviceIds.first,
                  deviceName: displayName,
                  panelColor: panelColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),

              if (!isZone) const SizedBox(height: 16),

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
                  draggableEnabled: !_moveLoading,
                  onToggleDevice: _toggleDevice,
                  onOpenDevice: (deviceId) {
                    final device = _devices.firstWhere(
                      (d) => _deviceId(d) == deviceId,
                      orElse: () => {'deviceId': deviceId},
                    );
                    context.push(
                      '/room/$deviceId',
                      extra: {
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
                        'temperature': device['temperature'] ?? 0,
                        'humidity': device['humidity'] ?? 0,
                        'manual_mode': _isManual(device),
                        'devices': [device],
                      },
                    );
                  },
                ),

              // ── Move targets (zone only) ──
              if (isZone) ...[
                const SizedBox(height: 16),
                _ZoneMoveTargets(
                  textColor: textColor,
                  mutedColor: mutedColor,
                  panelColor: panelColor,
                  onDropOutside: _moveDeviceOutsideZone,
                  onDropToNewZone: _moveDeviceToNewZone,
                  onTapOutside: _handleTapOutside,
                  onTapNewZone: _handleTapNewZone,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Settings popup menu ────────────────────────────────────────────────

class _SettingsMenu extends StatelessWidget {
  final VoidCallback onDelete;
  final Color textColor;
  final bool isDark;
  final bool isZone;

  const _SettingsMenu({
    required this.onDelete,
    required this.textColor,
    required this.isDark,
    required this.isZone,
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
        if (value == 'delete') onDelete();
      },
      itemBuilder: (ctx) => [
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
              Text(
                isZone ? 'zone.delete_zone'.tr() : 'zone.delete_device'.tr(),
                style: const TextStyle(
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: isOn
            ? const LinearGradient(
                colors: [
                  Color(0xFFFFD54F),
                  Color(0xFFFF9F43),
                  Color(0xFFFF6B35),
                ],
                stops: [0.0, 0.55, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isOn ? null : panelColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isOn
            ? [
                BoxShadow(
                  color: const Color(0xFFFF9F43).withValues(alpha: .45),
                  blurRadius: 40,
                  spreadRadius: 2,
                  offset: const Offset(0, 16),
                ),
              ]
            : null,
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
                  ? Colors.black.withValues(alpha: .12)
                  : Colors.white10,
              boxShadow: isOn
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .2),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ]
                  : [],
              border: Border.all(
                color: isOn
                    ? Colors.black.withValues(alpha: .15)
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
                  color: isOn ? const Color(0xFF1A0F00) : textColor,
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: isOn,
                onChanged: powerLoading ? null : onToggle,
                activeThumbColor: const Color(0xFF1A0F00),
                activeTrackColor: Colors.black.withValues(alpha: .2),
                inactiveThumbColor: _teal,
                inactiveTrackColor: _teal.withValues(alpha: .3),
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
                label: motionDetected ? 'device.motion'.tr() : 'device.no_motion'.tr(),
                color: motionDetected
                    ? (isOn ? const Color(0xFF1A0F00) : Colors.greenAccent)
                    : mutedColor,
              ),
              _StatusDot(
                active: isOnline,
                label: isOnline ? 'common.online'.tr() : 'common.offline'.tr(),
                color: isOnline
                    ? (isOn ? const Color(0xFF1A0F00) : Colors.greenAccent)
                    : Colors.redAccent,
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
  final bool isOn;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _BrightnessCard({
    required this.brightness,
    required this.isOn,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
    required this.onChanged,
    required this.onChangeEnd,
  });

  static const _presets = [
    _BrightnessPreset('🌑', 15, 'device.preset_min'),
    _BrightnessPreset('🌒', 40, 'device.preset_eco'),
    _BrightnessPreset('🌓', 70, 'device.preset_default'),
    _BrightnessPreset('🌕', 100, 'device.preset_max'),
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
                'device.brightness'.tr(),
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
                  color: _kA2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Slider
          Opacity(
            opacity: isOn ? 1.0 : 0.4,
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: _kA2,
                inactiveTrackColor: _kA2.withValues(alpha: .2),
                thumbColor: _kA2,
                overlayColor: _kA2.withValues(alpha: .1),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: brightness.clamp(0, 100),
                min: 0,
                max: 100,
                onChanged: isOn ? onChanged : null,
                onChangeEnd: isOn ? onChangeEnd : null,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Preset buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _presets.map((preset) {
              final selected =
                  (brightness - preset.value).abs() < 5 && brightness > 0;
              return GestureDetector(
                onTap: isOn
                    ? () {
                        onChanged(preset.value.toDouble());
                        onChangeEnd(preset.value.toDouble());
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 56,
                  height: 68,
                  decoration: BoxDecoration(
                    color: selected
                        ? _kA2.withValues(alpha: .15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? _kA2.withValues(alpha: .6)
                          : Colors.white12,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(preset.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(height: 3),
                      Text(
                        preset.label.tr(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white60,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
  final String label;
  const _BrightnessPreset(this.emoji, this.value, this.label);
}

// ── Mode card ──────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final String deviceMode;
  final bool modeLoading;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<String> onChanged;

  const _ModeCard({
    required this.deviceMode,
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
            'device.mode_section'.tr(),
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
                  label: 'device.mode_auto'.tr(),
                  emoji: '🤖',
                  selected: deviceMode == 'auto',
                  loading: modeLoading && deviceMode == 'auto',
                  onTap: () => onChanged('auto'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'device.mode_manual'.tr(),
                  emoji: '✋',
                  selected: deviceMode == 'manual',
                  loading: modeLoading && deviceMode == 'manual',
                  onTap: () => onChanged('manual'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ModeButton(
                  label: 'device.mode_schedule'.tr(),
                  emoji: '⏰',
                  selected: deviceMode == 'schedule',
                  loading: modeLoading && deviceMode == 'schedule',
                  onTap: () => onChanged('schedule'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderCol = selected
        ? Colors.transparent
        : (isDark ? Colors.white24 : const Color(0xFFD0D5E0));
    final textCol = selected
        ? const Color(0xFF1A0F00)
        : (isDark ? Colors.white60 : const Color(0xFF6D7481));
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [_kA1, _kA2, _kA3],
                  stops: [0.0, 0.55, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : (isDark ? Colors.transparent : const Color(0xFFF2F4F8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderCol, width: 1),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kA2),
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
                      color: textCol,
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
  final bool draggableEnabled;
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
    required this.draggableEnabled,
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
                'device.panels_in_zone'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kA1, _kA3],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${devices.length} ${'common.pcs'.tr()}',
                  style: const TextStyle(
                    color: Color(0xFF1A0F00),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final useSingleColumn = constraints.maxWidth < 360;
            final crossAxisCount = useSingleColumn ? 1 : 2;
            final panelHeight = useSingleColumn ? 184.0 : 212.0;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: devices.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                mainAxisExtent: panelHeight,
              ),
              itemBuilder: (context, index) {
                final device = devices[index];
                final id = _id(device);
                final isOn = deviceStates[id] ?? false;
                final isLoading = deviceLoading.contains(id);
                final name = (device['name'] ?? device['deviceId'] ?? 'device.panel'.tr())
                    .toString();
                final brightness = _RoomScreenState._normBrightness(
                  (device['brightness'] as num?)?.toDouble() ?? 0,
                ).round();
                final battery =
                    (device['batteryPercent'] ?? device['battery'] as num?)
                        ?.toInt() ??
                    0;
                final motion = device['motion_active'] == true;
                final online = device['connected'] != false;

                final panel = _PanelCard(
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

                if (!draggableEnabled) {
                  return panel;
                }

                return LongPressDraggable<_RoomDraggedPanel>(
                  data: _RoomDraggedPanel(deviceId: id, name: name),
                  maxSimultaneousDrags: 1,
                  rootOverlay: true,
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  onDragStarted: HapticService.light,
                  feedback: Material(
                    color: Colors.transparent,
                    child: Transform.rotate(
                      angle: -0.05,
                      child: SizedBox(
                        width: 160,
                        height: 224,
                        child: _PanelCard(
                          deviceId: id,
                          name: name,
                          isOn: isOn,
                          isLoading: true,
                          brightness: brightness,
                          battery: battery,
                          motion: motion,
                          online: online,
                          panelColor: panelColor,
                          softPanel: softPanel,
                          borderColor: borderColor,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          dragging: true,
                          onToggle: () {},
                          onTap: () {},
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.25,
                    child: IgnorePointer(child: panel),
                  ),
                  child: panel,
                );
              },
            );
          },
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
  final bool dragging;
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
    this.dragging = false,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = _kA2;
    final activeBg = isOn
        ? const LinearGradient(
            colors: [Color(0x2EFFD54F), Color(0x08FF6B35)],
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
          boxShadow: dragging
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: .25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
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
              'device.standalone_panel'.tr(),
              style: TextStyle(
                color: isOn ? activeColor : mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$brightness%  •  ${'device.bat_abbr'.tr()} $battery%',
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
                  label: motion ? 'device.motion_short'.tr() : 'device.no_motion_short'.tr(),
                  color: motion ? Colors.greenAccent : mutedColor,
                  small: true,
                ),
                _StatusDot(
                  active: online,
                  label: online ? 'common.online'.tr() : 'common.offline'.tr(),
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

class _RoomDraggedPanel {
  final String deviceId;
  final String name;

  const _RoomDraggedPanel({required this.deviceId, required this.name});
}

class _ZoneMoveTargets extends StatelessWidget {
  final Color textColor;
  final Color mutedColor;
  final Color panelColor;
  final Future<void> Function(_RoomDraggedPanel payload) onDropOutside;
  final Future<void> Function(_RoomDraggedPanel payload) onDropToNewZone;
  final Future<void> Function() onTapOutside;
  final Future<void> Function() onTapNewZone;

  const _ZoneMoveTargets({
    required this.textColor,
    required this.mutedColor,
    required this.panelColor,
    required this.onDropOutside,
    required this.onDropToNewZone,
    required this.onTapOutside,
    required this.onTapNewZone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'zone.move_panel'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'zone.move_panel_hint'.tr(),
            style: TextStyle(color: mutedColor, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _RoomDropTarget(
                  icon: Icons.open_in_full_rounded,
                  label: 'zone.move_out_of_zone'.tr(),
                  hint: 'zone.remove_from_zone'.tr(),
                  onAccept: onDropOutside,
                  onTap: onTapOutside,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoomDropTarget(
                  icon: Icons.create_new_folder_rounded,
                  label: 'zone.new_zone'.tr(),
                  hint: 'zone.create_and_move'.tr(),
                  onAccept: onDropToNewZone,
                  onTap: onTapNewZone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomDropTarget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Future<void> Function(_RoomDraggedPanel payload) onAccept;
  final Future<void> Function() onTap;

  const _RoomDropTarget({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onAccept,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg = isDark ? const Color(0xFF1E222C) : const Color(0xFFF3F5F9);
    final border = isDark ? const Color(0xFF313746) : const Color(0xFFD8DDE8);
    final text = isDark ? Colors.white : const Color(0xFF161A22);
    final muted = isDark ? Colors.white60 : const Color(0xFF6D7481);

    return DragTarget<_RoomDraggedPanel>(
      onWillAcceptWithDetails: (details) {
        return details.data.deviceId.trim().isNotEmpty;
      },
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFFFD54F).withValues(alpha: .16)
                : baseBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? const Color(0xFFFFD54F) : border,
              width: active ? 2 : 1.2,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: const Color(0xFFFFD54F).withValues(alpha: .22),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? const Color(0xFFFFD54F) : text,
                size: 22,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                active ? 'common.release'.tr() : hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? const Color(0xFFFFD54F) : muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        );
      },
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
        gradient: value
            ? const LinearGradient(
                colors: [_kA1, _kA3],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: value ? null : Colors.white24,
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
  final double temperature;
  final double humidity;
  final bool motionDetected;
  final bool isOnline;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;

  const _SensorCard({
    required this.lux,
    required this.battery,
    required this.temperature,
    required this.humidity,
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
            icon: Icons.thermostat_rounded,
            iconColor: const Color(0xFFFF7043),
            title: 'device.temperature'.tr(),
            value: '${temperature.toStringAsFixed(1)} °C',
            valueColor: const Color(0xFFFF7043),
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 14),
          _Row(
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFF42A5F5),
            title: 'device.humidity'.tr(),
            value: '${humidity.toStringAsFixed(1)} %',
            valueColor: const Color(0xFF42A5F5),
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 14),
          _Row(
            icon: Icons.wb_sunny_outlined,
            iconColor: const Color(0xFFF7931A),
            title: 'device.illuminance'.tr(),
            value: '$lux lux',
            valueColor: const Color(0xFFF7931A),
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 14),
          _Row(
            icon: Icons.battery_charging_full_rounded,
            iconColor: battery < 20 ? Colors.redAccent : Colors.green,
            title: 'device.battery_charge'.tr(),
            value: '$battery%',
            valueColor: battery < 20 ? Colors.redAccent : Colors.green,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 14),
          _Row(
            icon: Icons.motion_photos_on_outlined,
            iconColor: motionDetected ? Colors.green : mutedColor,
            title: 'device.motion'.tr(),
            value: motionDetected ? 'device.motion_detected'.tr() : 'common.no'.tr(),
            valueColor: motionDetected ? Colors.green : mutedColor,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
          const SizedBox(height: 14),
          _Row(
            icon: Icons.wifi_rounded,
            iconColor: isOnline ? Colors.green : Colors.redAccent,
            title: 'common.status'.tr(),
            value: isOnline ? 'common.online'.tr() : 'common.offline'.tr(),
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
          child: Text(title, style: TextStyle(fontSize: 15, color: textColor)),
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
              : (isDark ? const Color(0xFF262A32) : const Color(0xFFE2E6EF)),
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


// ── Night guard card ────────────────────────────────────────────────────

class _NightGuardCard extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<bool> onChanged;
  final VoidCallback onSchedule;

  const _NightGuardCard({
    required this.enabled,
    required this.loading,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
    required this.onChanged,
    required this.onSchedule,
  });

  String _fmt(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    const guardColor = Color(0xFF64D2FF);
    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: guardColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.shield_moon_outlined,
                    color: guardColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'night_guard.title'.tr(),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'night_guard.hint'.tr(),
                        style: TextStyle(color: mutedColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: enabled,
                        onChanged: onChanged,
                        activeThumbColor: guardColor,
                      ),
              ],
            ),
          ),
          // Time window row
          InkWell(
            onTap: onSchedule,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: guardColor.withValues(alpha: 0.07),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_outlined, color: guardColor, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'night_guard.guard_period_label'.tr(namedArgs: {'start': _fmt(startHour, startMinute), 'end': _fmt(endHour, endMinute)}),
                    style: TextStyle(
                      color: mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: guardColor, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Device quick-action buttons ─────────────────────────────────────────

class _DeviceActionsCard extends StatelessWidget {
  final String deviceId;
  final String deviceName;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;

  const _DeviceActionsCard({
    required this.deviceId,
    required this.deviceName,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    if (deviceId.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'device.management'.tr(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  icon: Icons.troubleshoot_outlined,
                  label: 'diagnostics.title'.tr(),
                  color: const Color(0xFF30D158),
                  onTap: () => context.push(
                    '/diagnostics/$deviceId',
                    extra: {'name': deviceName},
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.error_outline,
                  label: 'diagnostics.errors'.tr(),
                  color: const Color(0xFFFF3B30),
                  onTap: () => context.push(
                    '/errors/$deviceId',
                    extra: {'name': deviceName},
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.build_outlined,
                  label: 'maintenance.short'.tr(),
                  color: const Color(0xFFFFD54F),
                  onTap: () => context.push(
                    '/maintenance/$deviceId',
                    extra: {'name': deviceName},
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
