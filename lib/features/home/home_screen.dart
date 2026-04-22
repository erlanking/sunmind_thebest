import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';
import 'package:sunmind_thebest/core/services/session_cleanup_service.dart';
import 'package:sunmind_thebest/core/widgets/skeleton_loader.dart';
import 'package:sunmind_thebest/models/notification_model.dart';

const _accent = Color(0xFFFFD54F);
const _card = Color(0xFF1A1A1A);
const _bg = Color(0xFF0D0D0D);
const _muted = Color(0xFF6E6E73);
const _border = Color(0xFF2C2C2E);
const _standaloneAssignment = '__standalone__';

const List<Color> _roomColors = [
  Color(0xFFFFD54F),
  Color(0xFF42A5F5),
  Color(0xFF4CAF50),
  Color(0xFF26C6DA),
  Color(0xFFAB47BC),
  Color(0xFFFF7043),
  Color(0xFFEC407A),
  Color(0xFFEF5350),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();

  bool _zonesLoading = true;
  bool _profileLoading = false;
  bool _powerLoading = false;
  Timer? _refreshTimer;
  String _userName = 'Пользователь';
  String? _zonesError;

  Map<String, Map<String, dynamic>> _zoneMeta = {};
  Map<String, Map<String, dynamic>> _deviceMeta = {};
  Map<String, String> _deviceZoneAssignments = {};
  Set<String> _hiddenDeviceIds = {};

  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _cards = [];

  bool get _hasCards => _cards.isNotEmpty;

  bool get _anyOn => _cards.any((card) => card['on'] == true);

  @override
  void initState() {
    super.initState();
    _initialize();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchZones();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadLocalState();
    await _loadProfile();
    await _fetchZones();
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _screenBg(BuildContext context) =>
      _isDark(context) ? _bg : const Color(0xFFF2F2F7);

  Color _cardColor(BuildContext context) =>
      _isDark(context) ? _card : Colors.white;

  Color _borderColor(BuildContext context) =>
      _isDark(context) ? _border : const Color(0xFFE5E5EA);

  Color _textColor(BuildContext context) =>
      _isDark(context) ? Colors.white : const Color(0xFF1C1C1E);

  Color _mutedColor(BuildContext context) =>
      _isDark(context) ? _muted : const Color(0xFF8E8E93);

  Future<void> _loadLocalState() async {
    _zoneMeta = await SessionCleanupService.loadZoneMeta();
    _deviceMeta = await SessionCleanupService.loadDeviceMeta();
    _deviceZoneAssignments =
        await SessionCleanupService.loadDeviceZoneAssignments();
    _hiddenDeviceIds = await SessionCleanupService.loadHiddenDevices();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _persistZoneMeta() async {
    await SessionCleanupService.saveZoneMeta(_zoneMeta);
  }

  Future<void> _persistDeviceMeta() async {
    await SessionCleanupService.saveDeviceMeta(_deviceMeta);
  }

  Future<void> _persistDeviceAssignments() async {
    await SessionCleanupService.saveDeviceZoneAssignments(
      _deviceZoneAssignments,
    );
  }

  Future<void> _persistHiddenDevices() async {
    await SessionCleanupService.saveHiddenDevices(_hiddenDeviceIds);
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _profileLoading = true);
    try {
      final me = await _api.me();
      if (!mounted) return;
      final nextName = (me['name'] as String?)?.trim();
      if (nextName != null && nextName.isNotEmpty) {
        setState(() => _userName = nextName);
      }
    } catch (_) {
      // Keep fallback name when profile endpoint is unavailable.
    } finally {
      if (mounted) {
        setState(() => _profileLoading = false);
      }
    }
  }

  Future<void> _fetchZones() async {
    if (!mounted) return;
    setState(() {
      _zonesLoading = true;
      _zonesError = null;
    });

    try {
      final zones = await _api.getZones();
      final devices = await _api.getDevices();
      _devices = _mergeDeviceSources(zones, devices).where((device) {
        final deviceId = _deviceIdOf(device);
        return deviceId.isNotEmpty && !_hiddenDeviceIds.contains(deviceId);
      }).toList();
      _rebuildCards();
    } catch (_) {
      if (mounted) {
        setState(() => _zonesError = 'Не удалось загрузить панели и зоны');
      }
    } finally {
      if (mounted) {
        setState(() => _zonesLoading = false);
      }
    }
  }

  void _rebuildCards() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    final standalone = <Map<String, dynamic>>[];

    for (final device in _devices) {
      final zoneKey = _resolveZoneKey(device);
      if (zoneKey == null) {
        standalone.add(device);
        continue;
      }
      grouped.putIfAbsent(zoneKey, () => <Map<String, dynamic>>[]).add(device);
    }

    final cards = <Map<String, dynamic>>[];
    var colorIndex = 0;

    final zoneKeys = grouped.keys.toList()..sort();
    for (final zoneKey in zoneKeys) {
      cards.add(_buildZoneCard(zoneKey, grouped[zoneKey]!, colorIndex));
      colorIndex += 1;
    }

    standalone.sort((a, b) {
      return _displayDeviceName(
        a,
      ).toLowerCase().compareTo(_displayDeviceName(b).toLowerCase());
    });
    for (final device in standalone) {
      cards.add(_buildDeviceCard(device, colorIndex));
      colorIndex += 1;
    }

    if (!mounted) return;
    setState(() => _cards = cards);
  }

  Future<void> _setAllPower(bool value) async {
    if (_cards.isEmpty || _powerLoading) return;
    HapticService.toggle();

    final previous = _cards
        .map((card) => Map<String, dynamic>.from(card))
        .toList();
    setState(() {
      _powerLoading = true;
      for (final card in _cards) {
        card['on'] = value;
      }
    });

    try {
      for (final card in _cards) {
        await _sendPowerCommand(card, value);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cards = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить состояние зон: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _powerLoading = false);
      }
    }
  }

  Future<void> _toggleCard(String cardId) async {
    final index = _cards.indexWhere((card) => card['id'] == cardId);
    if (index == -1 || _powerLoading) return;

    HapticService.toggle();
    final previous = _cards[index]['on'] == true;
    final next = !previous;
    final card = _cards[index];

    setState(() {
      _cards[index]['on'] = next;
    });

    try {
      await _sendPowerCommand(card, next);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cards[index]['on'] = previous;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось управлять зоной: $e')));
    }
  }

  Future<void> _openCard(Map<String, dynamic> card) async {
    final result = await context.push('/room/${card['id']}', extra: card);
    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      await _handleRoomAction(result);
    }
  }

  Future<void> _handleRoomAction(Map<String, dynamic> action) async {
    final type = action['action']?.toString();
    switch (type) {
      case 'renameZone':
        final zoneKey = action['zoneKey']?.toString() ?? '';
        final zoneId = action['zoneId']?.toString() ?? '';
        final name = action['name']?.toString().trim() ?? '';
        if (zoneKey.isEmpty || zoneId.isEmpty || name.isEmpty) return;
        await _api.updateZone(zoneId, name: name);
        _zoneMeta[zoneKey] = {...?_zoneMeta[zoneKey], 'name': name};
        await _persistZoneMeta();
        await _fetchZones();
        break;
      case 'renameDevice':
        final deviceId = action['deviceId']?.toString() ?? '';
        final name = action['name']?.toString().trim() ?? '';
        if (deviceId.isEmpty || name.isEmpty) return;
        await _api.updateDevice(deviceId, name: name);
        _deviceMeta[deviceId] = {...?_deviceMeta[deviceId], 'name': name};
        await _persistDeviceMeta();
        await _fetchZones();
        break;
      case 'deleteZone':
        final zoneKey = action['zoneKey']?.toString() ?? '';
        final zoneId = action['zoneId']?.toString() ?? '';
        if (zoneKey.isEmpty || zoneId.isEmpty) return;
        final deviceIds =
            (action['deviceIds'] as List?)
                ?.map((id) => id.toString())
                .where((id) => id.isNotEmpty)
                .toList() ??
            <String>[];
        for (final deviceId in deviceIds) {
          await _api.removeDeviceFromZone(zoneId, deviceId);
          _deviceZoneAssignments[deviceId] = _standaloneAssignment;
        }
        try {
          await _api.deleteZone(zoneId);
        } catch (_) {
          // Если сервер удаляет пустую зону автоматически после открепления,
          // повторный DELETE может вернуть ошибку — не блокируем UI из-за этого.
        }
        _zoneMeta.remove(zoneKey);
        await _persistDeviceAssignments();
        await _persistZoneMeta();
        await _fetchZones();
        break;
      case 'deleteDevice':
        final deviceId = action['deviceId']?.toString() ?? '';
        if (deviceId.isEmpty) return;
        final deviceName = (_deviceMeta[deviceId]?['name'] ?? deviceId).toString();
        await _api.deleteDevice(deviceId);
        _deviceZoneAssignments.remove(deviceId);
        await _persistDeviceAssignments();
        _devices.removeWhere((device) => _deviceIdOf(device) == deviceId);
        await _fetchZones();
        if (mounted) {
          context.read<NotificationProvider>().addNotification(NotificationModel(
            id: 'device_removed_${DateTime.now().microsecondsSinceEpoch}',
            title: 'notif_device_removed_title'.tr(),
            body: 'notif_device_removed_body'.tr(namedArgs: {'name': deviceName}),
            type: NotificationType.system,
            timestamp: DateTime.now(),
          ));
        }
        break;
    }
  }

  void _addZoneFromResult(Map result) {
    final deviceId = (result['deviceId'] ?? '').toString().trim();
    final zoneName = (result['zoneName'] ?? '').toString().trim();
    if (deviceId.isEmpty || zoneName.isEmpty) return;

    final isNewZone = _findZoneKeyByName(zoneName) == null;
    final zoneKey = _findZoneKeyByName(zoneName) ?? _zoneKeyFromName(zoneName);
    _deviceZoneAssignments[deviceId] = zoneKey;
    _hiddenDeviceIds.remove(deviceId);

    final preserveExistingMeta = result['preserveExistingMeta'] == true;
    final existing = _zoneMeta[zoneKey] ?? const <String, dynamic>{};
    _zoneMeta[zoneKey] = {
      ...existing,
      'name': zoneName,
      if (!preserveExistingMeta || !existing.containsKey('emoji'))
        'emoji': result['emoji'] ?? existing['emoji'] ?? '💡',
      if (!preserveExistingMeta || !existing.containsKey('colorIndex'))
        'colorIndex': result['colorIndex'] ?? existing['colorIndex'] ?? 0,
    };

    _persistDeviceAssignments();
    _persistHiddenDevices();
    _persistZoneMeta();
    _fetchZones();

    if (mounted) {
      final notifProvider = context.read<NotificationProvider>();
      notifProvider.addNotification(NotificationModel(
        id: 'device_added_${DateTime.now().microsecondsSinceEpoch}',
        title: 'notif_device_added_title'.tr(),
        body: 'notif_device_added_body'.tr(namedArgs: {'name': deviceId}),
        type: NotificationType.system,
        timestamp: DateTime.now(),
      ));
      if (isNewZone) {
        notifProvider.addNotification(NotificationModel(
          id: 'zone_created_${DateTime.now().microsecondsSinceEpoch}',
          title: 'notif_zone_created_title'.tr(),
          body: 'notif_zone_created_body'.tr(namedArgs: {'zone': zoneName}),
          type: NotificationType.system,
          timestamp: DateTime.now(),
        ));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Панель добавлена в зону "$zoneName"')),
      );
    }
  }

  Future<void> _scanAndAddDevice() async {
    final result = await context.push('/scan-device');
    if (!mounted) return;
    if (result is Map) {
      _addZoneFromResult(result);
    }
  }

  List<Map<String, dynamic>> _normalizeDevicesFromZones(
    List<Map<String, dynamic>> zones,
  ) {
    final byId = <String, Map<String, dynamic>>{};

    for (final zone in zones) {
      final backendZoneName = (zone['name'] ?? '').toString().trim();
      final backendZoneId = zone['id']?.toString();

      for (final device in _extractDevices(zone)) {
        final deviceId = _deviceIdOf(device);
        if (deviceId.isEmpty) continue;

        final current =
            byId[deviceId] ?? <String, dynamic>{'deviceId': deviceId};
        current.addAll(device);
        current['deviceId'] = deviceId;

        if (backendZoneName.isNotEmpty) {
          current['backendZoneName'] = backendZoneName;
        }
        if (backendZoneId != null && backendZoneId.isNotEmpty) {
          current['backendZoneId'] = backendZoneId;
        }

        byId[deviceId] = current;
      }
    }

    return byId.values.toList();
  }

  List<Map<String, dynamic>> _mergeDeviceSources(
    List<Map<String, dynamic>> zones,
    List<Map<String, dynamic>> devices,
  ) {
    final zoneDevices = _normalizeDevicesFromZones(zones);
    final merged = <String, Map<String, dynamic>>{};

    for (final device in devices) {
      final deviceId = _deviceIdOf(device);
      if (deviceId.isEmpty) continue;
      merged[deviceId] = {...device, 'deviceId': deviceId};

      final zone = device['zone'];
      if (zone is Map) {
        final zoneMap = zone.cast<String, dynamic>();
        final zoneId = zoneMap['id']?.toString() ?? '';
        final zoneName = zoneMap['name']?.toString() ?? '';
        if (zoneId.isNotEmpty) {
          merged[deviceId]!['backendZoneId'] = zoneId;
        }
        if (zoneName.trim().isNotEmpty) {
          merged[deviceId]!['backendZoneName'] = zoneName.trim();
        }
      }

      final directZoneId = device['zoneId']?.toString() ?? '';
      if (directZoneId.isNotEmpty) {
        merged[deviceId]!['backendZoneId'] = directZoneId;
      }
      final directZoneName = (device['zoneName'] ?? '').toString().trim();
      if (directZoneName.isNotEmpty) {
        merged[deviceId]!['backendZoneName'] = directZoneName;
      }
    }

    for (final device in zoneDevices) {
      final deviceId = _deviceIdOf(device);
      if (deviceId.isEmpty) continue;
      merged[deviceId] = {
        ...?merged[deviceId],
        ...device,
        'deviceId': deviceId,
      };
    }

    return merged.values.toList();
  }

  List<Map<String, dynamic>> _extractDevices(Map<String, dynamic> zone) {
    final devices = zone['devices'];
    if (devices is List && devices.isNotEmpty) {
      return devices.whereType<Map>().map((raw) {
        final map = Map<String, dynamic>.from(raw);
        if (!map.containsKey('name') && zone['deviceName'] != null) {
          map['name'] = zone['deviceName'];
        }
        return map;
      }).toList();
    }

    final deviceId = zone['deviceId']?.toString() ?? '';
    if (deviceId.isEmpty) return const <Map<String, dynamic>>[];

    return [
      <String, dynamic>{
        'deviceId': deviceId,
        'name': zone['deviceName'] ?? zone['name'],
        'brightness': zone['brightness'],
        'batteryPercent': zone['batteryPercent'] ?? zone['battery'],
        'lux': zone['lux'],
        'led_state': zone['led_state'],
        'manual_mode': zone['manual_mode'],
        'motion_active': zone['motion_active'],
        'connected': zone['connected'],
      },
    ];
  }

  String _deviceIdOf(Map<String, dynamic> device) {
    return (device['deviceId'] ?? '').toString().trim();
  }

  String? _resolveZoneKey(Map<String, dynamic> device) {
    final deviceId = _deviceIdOf(device);
    if (deviceId.isEmpty) return null;

    final local = _deviceZoneAssignments[deviceId];
    if (local == _standaloneAssignment) return null;

    final backendZoneId = (device['backendZoneId'] ?? '').toString().trim();
    if (backendZoneId.isNotEmpty) {
      return 'zone:$backendZoneId';
    }

    if (local != null && local.isNotEmpty) return local;

    final backendZoneName = (device['backendZoneName'] ?? '').toString().trim();
    if (backendZoneName.isEmpty) return null;
    return _zoneKeyFromName(backendZoneName);
  }

  String _zoneKeyFromName(String name) {
    return 'zone:${_slugify(name)}';
  }

  String _slugify(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zа-я0-9_]+', caseSensitive: false), '');
  }

  String? _findZoneKeyByName(String zoneName) {
    final normalized = zoneName.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final entry in _zoneMeta.entries) {
      final currentName = (entry.value['name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (currentName == normalized) return entry.key;
    }

    for (final card in _cards) {
      if (card['kind'] != 'zone') continue;
      final currentName = (card['name'] ?? '').toString().trim().toLowerCase();
      if (currentName == normalized) {
        return card['zoneKey']?.toString();
      }
    }

    return null;
  }

  Map<String, dynamic> _buildZoneCard(
    String zoneKey,
    List<Map<String, dynamic>> devices,
    int index,
  ) {
    final meta = _zoneMeta[zoneKey] ?? const <String, dynamic>{};
    final first = devices.first;
    final brightnessValues = devices
        .map((device) => _asDouble(device['brightness']))
        .where((value) => value > 0)
        .toList();
    final batteryValues = devices
        .map((device) => _asInt(device['batteryPercent'] ?? device['battery']))
        .where((value) => value > 0)
        .toList();
    final luxValues = devices
        .map((device) => _asInt(device['lux']))
        .where((value) => value > 0)
        .toList();
    final deviceIds = devices
        .map(_deviceIdOf)
        .where((id) => id.isNotEmpty)
        .toList();

    final colorIndex = (meta['colorIndex'] as num?)?.toInt() ?? index;
    final color = _roomColors[colorIndex % _roomColors.length];

    return {
      'id': first['backendZoneId']?.toString().isNotEmpty == true
          ? 'zone:${first['backendZoneId']}'
          : 'zone:$zoneKey',
      'kind': 'zone',
      'zoneKey': zoneKey,
      'zoneId': (first['backendZoneId'] ?? '').toString(),
      'name': (meta['name'] ?? first['backendZoneName'] ?? 'Зона').toString(),
      'emoji': (meta['emoji'] ?? '💡').toString(),
      'color': color,
      'on': devices.any(
        (device) => device['led_state']?.toString().toUpperCase() == 'ON',
      ),
      'motion': devices.any((device) => device['motion_active'] == true),
      'online': devices.every((device) => device['connected'] != false),
      'brightness': brightnessValues.isEmpty
          ? 0.0
          : brightnessValues.reduce((a, b) => a + b) / brightnessValues.length,
      'batteryPercent': batteryValues.isEmpty
          ? 0
          : batteryValues.reduce((a, b) => a < b ? a : b),
      'lux': luxValues.isEmpty
          ? 0
          : (luxValues.reduce((a, b) => a + b) / luxValues.length).round(),
      'deviceCount': deviceIds.length,
      'deviceIds': deviceIds,
      'deviceId': deviceIds.isEmpty ? '' : deviceIds.first,
      'devices': devices,
    };
  }

  Map<String, dynamic> _buildDeviceCard(
    Map<String, dynamic> device,
    int index,
  ) {
    final deviceId = _deviceIdOf(device);
    return {
      'id': 'device:$deviceId',
      'kind': 'device',
      'deviceId': deviceId,
      'deviceIds': [deviceId],
      'deviceCount': 1,
      'name': _displayDeviceName(device),
      'emoji': (_deviceMeta[deviceId]?['emoji'] ?? '💡').toString(),
      'color': _roomColors[index % _roomColors.length],
      'on': device['led_state']?.toString().toUpperCase() == 'ON',
      'motion': device['motion_active'] == true,
      'online': device['connected'] != false,
      'brightness': _asDouble(device['brightness']),
      'batteryPercent': _asInt(device['batteryPercent'] ?? device['battery']),
      'lux': _asInt(device['lux']),
      'devices': [device],
    };
  }

  String _displayDeviceName(Map<String, dynamic> device) {
    final deviceId = _deviceIdOf(device);
    final localName = (_deviceMeta[deviceId]?['name'] ?? '').toString().trim();
    if (localName.isNotEmpty) return localName;

    final backendName = (device['name'] ?? '').toString().trim();
    if (backendName.isNotEmpty) return backendName;

    return deviceId.isEmpty ? 'Панель' : deviceId;
  }

  List<String> _deviceIdsFromCard(Map<String, dynamic> card) {
    final ids =
        (card['deviceIds'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList() ??
        <String>[];
    if (ids.isNotEmpty) return ids;

    final deviceId = card['deviceId']?.toString() ?? '';
    return deviceId.isEmpty ? <String>[] : <String>[deviceId];
  }

  Future<void> _sendPowerCommand(Map<String, dynamic> card, bool value) async {
    final zoneId = card['zoneId']?.toString() ?? '';
    if ((card['kind'] ?? '') == 'zone' && zoneId.isNotEmpty) {
      await _api.controlZone(zoneId, on: value);
      return;
    }

    await _api.setDevicesLed(_deviceIdsFromCard(card), value);
  }

  int _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBg(context),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                HapticService.medium();
                await _loadProfile();
                await _fetchZones();
              },
              color: _accent,
              backgroundColor: _card,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: ListView(
                  children: [
                    _greeting(),
                    const SizedBox(height: 18),
                    _masterSwitch(),
                    const SizedBox(height: 18),
                    _roomsHeader(),
                    const SizedBox(height: 12),
                    _roomsBody(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            Positioned(right: 18, bottom: 100, child: _fab()),
          ],
        ),
      ),
    );
  }

  Widget _greeting() {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Доброе утро,'
        : hour < 17
            ? 'Добрый день,'
            : 'Добрый вечер,';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: _mutedColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _profileLoading ? '...' : _userName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _textColor(context),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/notifications'),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _cardColor(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: _borderColor(context)),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.notifications_outlined,
                  color: _textColor(context),
                  size: 20,
                ),
              ),
              if (unreadCount > 0)
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _screenBg(context),
                      width: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _masterSwitch() {
    final canControlAll = _hasCards;
    final targetOn = canControlAll ? !_anyOn : false;

    return GestureDetector(
      onTap: !canControlAll || _powerLoading
          ? null
          : () => _setAllPower(targetOn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isDark(context)
                    ? Colors.white10
                    : const Color(0xFFF2F4F8),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: const Text('💡', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !canControlAll
                        ? 'Включить все зоны'
                        : _anyOn
                        ? 'Выключить все зоны'
                        : 'Включить все зоны',
                    style: TextStyle(
                      color: _textColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    !canControlAll
                        ? 'Добавьте первую панель'
                        : 'Управляйте домом как одним целым',
                    style: TextStyle(
                      color: _mutedColor(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isDark(context)
                    ? const Color(0xFF262A32)
                    : const Color(0xFFF2F4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.power_settings_new,
                    size: 16,
                    color: _textColor(context),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    canControlAll ? (targetOn ? 'Вкл' : 'Выкл') : 'Вкл',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _textColor(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Зоны и панели',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textColor(context),
                letterSpacing: -0.3,
              ),
            ),
            if (_cards.isNotEmpty)
              Text(
                '${_cards.length} устройств',
                style: TextStyle(
                  color: _mutedColor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        GestureDetector(
          onTap: _scanAndAddDevice,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Добавить',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roomsBody() {
    if (_zonesLoading) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.96,
        children: const [RoomCardSkeleton(), RoomCardSkeleton()],
      );
    }

    if (_zonesError != null) {
      return Column(
        children: [
          Text(_zonesError!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _fetchZones,
            child: const Text('Повторить'),
          ),
        ],
      );
    }

    if (_cards.isEmpty) {
      return _emptyState();
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.68,
      children: _cards.map(_cardTile).toList(),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: _isDark(context) ? .08 : .12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _accent.withValues(alpha: .3),
                  _accent.withValues(alpha: .1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.home_outlined,
              size: 40,
              color: _accent.withValues(alpha: .9),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Пока нет панелей',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте панель, затем объединяйте несколько панелей в одну зону и управляйте ими как одной группой.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _mutedColor(context),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _scanAndAddDevice,
            icon: const Icon(Icons.add),
            label: const Text('Добавить панель'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTile(Map<String, dynamic> card) {
    return _ZoneCard(
      card: card,
      isDark: _isDark(context),
      powerLoading: _powerLoading,
      onTap: () => _openCard(card),
      onToggle: () => _toggleCard(card['id']?.toString() ?? ''),
    );
  }

  Widget _fab() {
    return GestureDetector(
      onTap: _scanAndAddDevice,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: _accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: .45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.black, size: 28),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _ZoneCard — анимированная карточка зоны/панели
// ═══════════════════════════════════════════════════════════════

class _ZoneCard extends StatefulWidget {
  final Map<String, dynamic> card;
  final bool isDark;
  final bool powerLoading;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _ZoneCard({
    required this.card,
    required this.isDark,
    required this.powerLoading,
    required this.onTap,
    required this.onToggle,
  });

  @override
  State<_ZoneCard> createState() => _ZoneCardState();
}

class _ZoneCardState extends State<_ZoneCard> {
  bool _pressed = false;

  int _asInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final color = card['color'] as Color;
    final on = card['on'] == true;
    final isDark = widget.isDark;

    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final mutedColor = isDark ? const Color(0xFF6E6E73) : const Color(0xFF8E8E93);
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);

    final isZoneCard = card['kind'] == 'zone';
    final deviceCount = _asInt(card['deviceCount']);
    final brightness = _asDouble(card['brightness']).round();
    final lux = _asInt(card['lux']);
    final battery = _asInt(card['batteryPercent']);
    final motion = card['motion'] == true;
    final online = card['online'] != false;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: on ? null : cardBg,
            gradient: on
                ? LinearGradient(
                    colors: [
                      color.withValues(alpha: .28),
                      color.withValues(alpha: .07),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: on ? color.withValues(alpha: .4) : borderColor,
              width: 1.2,
            ),
            boxShadow: on
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: .22),
                      blurRadius: 22,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? .18 : .04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: emoji icon + toggle
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: on
                          ? color.withValues(alpha: .22)
                          : (isDark
                                ? Colors.white10
                                : const Color(0xFFF2F2F7)),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: on
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: .35),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      card['emoji']?.toString() ?? '💡',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: widget.powerLoading ? null : widget.onToggle,
                    child: _CardToggle(value: on, color: color),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Name
              Text(
                card['name']?.toString() ?? 'Панель',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.2,
                  letterSpacing: -0.2,
                ),
              ),

              const SizedBox(height: 3),

              // Zone count / type
              Text(
                isZoneCard ? '$deviceCount устройств' : 'Устройство',
                style: TextStyle(
                  color: on ? color : mutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const Spacer(),

              // Stats line
              Text(
                '☀ $brightness%  ·  $lux lx  ·  🔋$battery%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 7),

              // Status dots
              Row(
                children: [
                  _Dot(
                    color: online ? const Color(0xFF30D158) : Colors.redAccent,
                    label: online ? 'Online' : 'Offline',
                    mutedColor: mutedColor,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  _Dot(
                    color: motion
                        ? const Color(0xFFFFD54F)
                        : mutedColor,
                    label: motion ? 'Движение' : 'Тихо',
                    mutedColor: mutedColor,
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom card toggle ─────────────────────────────────────────────────

class _CardToggle extends StatelessWidget {
  final bool value;
  final Color color;
  const _CardToggle({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: 44,
      height: 26,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: value ? color : Colors.white24,
        borderRadius: BorderRadius.circular(20),
        boxShadow: value
            ? [
                BoxShadow(
                  color: color.withValues(alpha: .4),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: value ? Colors.black : Colors.white70,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .15),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small status dot ────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  final Color mutedColor;
  final bool isDark;

  const _Dot({
    required this.color,
    required this.label,
    required this.mutedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: mutedColor,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
