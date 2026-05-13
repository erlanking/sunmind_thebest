import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';
import 'package:sunmind_thebest/core/services/notification_provider.dart';
import 'package:sunmind_thebest/core/services/offline_snapshot_service.dart';
import 'package:sunmind_thebest/core/services/session_cleanup_service.dart';
import 'package:sunmind_thebest/core/services/view_cache_service.dart';
import 'package:sunmind_thebest/core/widgets/skeleton_loader.dart';
import 'package:sunmind_thebest/models/notification_model.dart';

const _accent = Color(0xFFF7931A);  // kA2
const _card = Color(0xFF17171B);
const _bg = Color(0xFF0B0B0D);
const _muted = Color(0xFF6E6E75);
const _border = Color(0xFF26262D);
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
  final Map<String, GlobalKey> _zoneCardKeys = {};

  bool _zonesLoading = true;
  bool _profileLoading = false;
  bool _powerLoading = false;
  Timer? _refreshTimer;
  String _userName = 'Пользователь';
  String? _zonesError;
  bool _showOfflineSnapshotNotice = false;

  Map<String, Map<String, dynamic>> _zoneMeta = {};
  Map<String, Map<String, dynamic>> _deviceMeta = {};
  Map<String, String> _deviceZoneAssignments = {};
  Set<String> _hiddenDeviceIds = {};
  String? _snapZoneCardId;
  Offset? _lastDragGlobalPosition;
  bool _isDragging = false;

  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _cards = [];

  bool get _hasCards => _cards.isNotEmpty;

  bool get _anyOn => _cards.any((card) => card['on'] == true);

  @override
  void initState() {
    super.initState();
    _restoreHomeCache();
    _initialize();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchZones(showLoading: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadLocalState();
    await _restorePersistedHomeCache();
    if (!mounted) return;
    unawaited(_loadProfile(showLoading: _userName == 'Пользователь'));
    await _fetchZones(showLoading: _cards.isEmpty);
  }

  void _restoreHomeCache() {
    final cached = ViewCacheService.home;
    if (cached == null) return;
    _userName = cached.userName;
    _devices = cached.devices
        .map((device) => Map<String, dynamic>.from(device))
        .toList();
    _cards = cached.cards
        .map((card) => Map<String, dynamic>.from(card))
        .toList();
    _zonesLoading = false;
  }

  Future<void> _restorePersistedHomeCache() async {
    if (_cards.isNotEmpty) return;
    final cached = await OfflineSnapshotService.loadHomeSnapshot();
    if (cached == null || !mounted) return;

    final rawDevices = (cached['devices'] as List?) ?? const [];
    final rawCards = (cached['cards'] as List?) ?? const [];
    final cachedUserName = (cached['userName'] as String?)?.trim();

    setState(() {
      if (cachedUserName != null && cachedUserName.isNotEmpty) {
        _userName = cachedUserName;
      }
      _devices = rawDevices
          .whereType<Map>()
          .map((device) => Map<String, dynamic>.from(device))
          .toList();
      _cards = rawCards
          .whereType<Map>()
          .map((card) => _deserializeOfflineCard(Map<String, dynamic>.from(card)))
          .toList();
      _zonesLoading = false;
    });
  }

  Map<String, dynamic> _serializeOfflineCard(Map<String, dynamic> card) {
    final copy = Map<String, dynamic>.from(card);
    final color = copy['color'];
    if (color is Color) {
      copy['color'] = color.toARGB32();
    }
    return copy;
  }

  Map<String, dynamic> _deserializeOfflineCard(Map<String, dynamic> card) {
    final copy = Map<String, dynamic>.from(card);
    final color = copy['color'];
    if (color is int) {
      copy['color'] = Color(color);
    } else if (color is num) {
      copy['color'] = Color(color.toInt());
    }
    return copy;
  }

  Future<void> _saveHomeCache() async {
    ViewCacheService.home = HomeViewCache(
      userName: _userName,
      devices: _devices
          .map((device) => Map<String, dynamic>.from(device))
          .toList(),
      cards: _cards.map((card) => Map<String, dynamic>.from(card)).toList(),
    );
    await OfflineSnapshotService.saveHomeSnapshot({
      'userName': _userName,
      'devices': _devices
          .map((device) => Map<String, dynamic>.from(device))
          .toList(),
      'cards': _cards.map(_serializeOfflineCard).toList(),
    });
  }

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _screenBg(BuildContext context) =>
      _isDark(context) ? _bg : const Color(0xFFF6F5F1);

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

  Future<void> _loadProfile({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() => _profileLoading = true);
    }
    try {
      final me = await _api.me();
      if (!mounted) return;
      final nextName = (me['name'] as String?)?.trim();
      if (nextName != null && nextName.isNotEmpty) {
        setState(() => _userName = nextName);
        unawaited(_saveHomeCache());
      }
    } catch (_) {
      // Keep fallback name when profile endpoint is unavailable.
    } finally {
      if (mounted && showLoading) {
        setState(() => _profileLoading = false);
      }
    }
  }

  Future<void> _fetchZones({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _zonesLoading = true;
        _zonesError = null;
      });
    } else if (_zonesError != null) {
      setState(() => _zonesError = null);
    }

    try {
      final zones = await _api.getZones();
      final devices = await _api.getDevices();
      _devices = _mergeDeviceSources(zones, devices).where((device) {
        final deviceId = _deviceIdOf(device);
        return deviceId.isNotEmpty && !_hiddenDeviceIds.contains(deviceId);
      }).toList();
      _rebuildCards();
      _showOfflineSnapshotNotice = false;
      await _saveHomeCache();
    } catch (e) {
      if (!mounted) return;
      if (!showLoading) return; // silent background refresh — don't show offline banner
      final hasSnapshot = _cards.isNotEmpty;
      setState(() {
        if (hasSnapshot && ApiService.isOfflineError(e)) {
          _zonesError = null;
          _showOfflineSnapshotNotice = true;
        } else if (ApiService.isOfflineError(e)) {
          _zonesError =
              'Нет интернета. Подключитесь к сети, чтобы загрузить данные.';
        } else {
          _zonesError = 'Не удалось загрузить панели и зоны';
        }
      });
    } finally {
      if (mounted && showLoading) {
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
        SnackBar(
          content: Text(
            ApiService.isOfflineError(e)
                ? 'Включите интернет, чтобы управлять устройствами.'
                : 'Не удалось изменить состояние. Проверьте подключение устройства.',
          ),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.isOfflineError(e)
                ? 'Включите интернет, чтобы управлять устройствами.'
                : 'Не удалось включить/выключить. Устройство не отвечает.',
          ),
        ),
      );
    }
  }

  Future<void> _moveDeviceToZone(
    _DraggedDevicePayload dragged,
    Map<String, dynamic> zoneCard,
  ) async {
    final deviceId = dragged.deviceId.trim();
    final zoneId = zoneCard['zoneId']?.toString().trim() ?? '';
    final zoneKey = zoneCard['zoneKey']?.toString().trim() ?? '';
    final zoneName = zoneCard['name']?.toString().trim() ?? 'зону';

    if (deviceId.isEmpty || zoneId.isEmpty || zoneKey.isEmpty) {
      return;
    }

    final previousAssignment = _deviceZoneAssignments[deviceId];

    HapticService.medium();
    _deviceZoneAssignments[deviceId] = zoneKey;
    _rebuildCards();

    try {
      await _api.addDevicesToZone(zoneId, deviceIds: [deviceId]);
      await _persistDeviceAssignments();
      await _fetchZones(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Панель перенесена в "$zoneName"')),
      );
    } catch (e) {
      if (previousAssignment == null) {
        _deviceZoneAssignments.remove(deviceId);
      } else {
        _deviceZoneAssignments[deviceId] = previousAssignment;
      }
      _rebuildCards();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.isOfflineError(e)
                ? 'Включите интернет, чтобы управлять устройствами.'
                : 'Не удалось переместить панель в зону. Попробуйте ещё раз.',
          ),
        ),
      );
    }
  }

  GlobalKey _zoneCardKey(String cardId) {
    return _zoneCardKeys.putIfAbsent(
      cardId,
      () => GlobalKey(debugLabel: 'zone-card-$cardId'),
    );
  }

  Map<String, dynamic>? _cardById(String cardId) {
    for (final card in _cards) {
      if (card['id'] == cardId) return card;
    }
    return null;
  }

  double _distanceToRect(Offset point, Rect rect) {
    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : point.dx > rect.right
        ? point.dx - rect.right
        : 0.0;
    final dy = point.dy < rect.top
        ? rect.top - point.dy
        : point.dy > rect.bottom
        ? point.dy - rect.bottom
        : 0.0;
    return (dx * dx) + (dy * dy);
  }

  String? _nearestZoneCardId(Offset globalPosition) {
    const snapThreshold = 88.0;
    final maxDistance = snapThreshold * snapThreshold;

    String? nearestId;
    double? nearestDistance;

    for (final card in _cards) {
      if (card['kind'] != 'zone') continue;
      final zoneId = card['zoneId']?.toString().trim() ?? '';
      final cardId = card['id']?.toString() ?? '';
      if (zoneId.isEmpty || cardId.isEmpty) continue;

      final key = _zoneCardKeys[cardId];
      final context = key?.currentContext;
      if (context == null) continue;

      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;

      final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
      final distance = _distanceToRect(globalPosition, rect);
      if (distance > maxDistance) continue;

      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearestId = cardId;
      }
    }

    return nearestId;
  }

  void _updateSnapZone(Offset globalPosition) {
    _lastDragGlobalPosition = globalPosition;
    final nextZoneId = _nearestZoneCardId(globalPosition);
    if (nextZoneId == _snapZoneCardId) return;

    if (nextZoneId != null) {
      HapticService.light();
    }

    if (!mounted) return;
    setState(() => _snapZoneCardId = nextZoneId);
  }

  void _resetSnapZone() {
    _lastDragGlobalPosition = null;
    if (_snapZoneCardId == null || !mounted) return;
    setState(() => _snapZoneCardId = null);
  }

  Future<void> _handleDragEnd(
    _DraggedDevicePayload payload,
    bool wasAccepted,
  ) async {
    final snapZoneId =
        _snapZoneCardId ??
        (_lastDragGlobalPosition == null
            ? null
            : _nearestZoneCardId(_lastDragGlobalPosition!));
    _resetSnapZone();

    if (wasAccepted || snapZoneId == null || !mounted) return;

    final zoneCard = _cardById(snapZoneId);
    if (zoneCard == null) return;

    final confirmed = await _confirmDeviceMove(
      deviceName: payload.name,
      targetName: (zoneCard['name'] ?? 'зона').toString(),
    );
    if (!confirmed || !mounted) return;
    await _moveDeviceToZone(payload, zoneCard);
  }

  Future<bool> _confirmDeviceMove({
    required String deviceName,
    required String targetName,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Подтвердите перенос'),
            content: Text('Переместить "$deviceName" в "$targetName"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Переместить'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openCard(Map<String, dynamic> card) async {
    final result = await context.push('/room/${card['id']}', extra: card);
    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      await _handleRoomAction(result);
    } else {
      // Тихое обновление — подхватываем изменения яркости/вкл-выкл из комнаты
      await _fetchZones(showLoading: false);
    }
  }

  Future<void> _handleRoomAction(Map<String, dynamic> action) async {
    final type = action['action']?.toString();
    switch (type) {
      case 'refresh':
        await _fetchZones(showLoading: false);
        break;
      case 'renameZone':
        final zoneKey = action['zoneKey']?.toString() ?? '';
        final zoneId = action['zoneId']?.toString() ?? '';
        final name = action['name']?.toString().trim() ?? '';
        if (zoneKey.isEmpty || zoneId.isEmpty || name.isEmpty) return;
        await _api.updateZone(zoneId, name: name);
        _zoneMeta[zoneKey] = {...?_zoneMeta[zoneKey], 'name': name};
        await _persistZoneMeta();
        await _fetchZones(showLoading: false);
        break;
      case 'renameDevice':
        final deviceId = action['deviceId']?.toString() ?? '';
        final name = action['name']?.toString().trim() ?? '';
        if (deviceId.isEmpty || name.isEmpty) return;
        await _api.updateDevice(deviceId, name: name);
        _deviceMeta[deviceId] = {...?_deviceMeta[deviceId], 'name': name};
        await _persistDeviceMeta();
        await _fetchZones(showLoading: false);
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
        await _fetchZones(showLoading: false);
        break;
      case 'deleteDevice':
        final deviceId = action['deviceId']?.toString() ?? '';
        if (deviceId.isEmpty) return;
        final deviceName = (_deviceMeta[deviceId]?['name'] ?? deviceId)
            .toString();
        await _api.deleteDevice(deviceId);
        _deviceZoneAssignments.remove(deviceId);
        await _persistDeviceAssignments();
        _devices.removeWhere((device) => _deviceIdOf(device) == deviceId);
        await _fetchZones(showLoading: false);
        if (mounted) {
          context.read<NotificationProvider>().addNotification(
            NotificationModel(
              id: 'device_removed_${DateTime.now().microsecondsSinceEpoch}',
              title: 'notif_device_removed_title'.tr(),
              body: 'notif_device_removed_body'.tr(
                namedArgs: {'name': deviceName},
              ),
              type: NotificationType.system,
              timestamp: DateTime.now(),
            ),
          );
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
    _fetchZones(showLoading: false);

    if (mounted) {
      final notifProvider = context.read<NotificationProvider>();
      notifProvider.addNotification(
        NotificationModel(
          id: 'device_added_${DateTime.now().microsecondsSinceEpoch}',
          title: 'notif_device_added_title'.tr(),
          body: 'notif_device_added_body'.tr(namedArgs: {'name': deviceId}),
          type: NotificationType.system,
          timestamp: DateTime.now(),
        ),
      );
      if (isNewZone) {
        notifProvider.addNotification(
          NotificationModel(
            id: 'zone_created_${DateTime.now().microsecondsSinceEpoch}',
            title: 'notif_zone_created_title'.tr(),
            body: 'notif_zone_created_body'.tr(namedArgs: {'zone': zoneName}),
            type: NotificationType.system,
            timestamp: DateTime.now(),
          ),
        );
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
        'temperature': zone['temperature'],
        'humidity': zone['humidity'],
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
    final temperatureValues = devices
        .map((device) => _asDouble(device['temperature']))
        .where((value) => value > 0)
        .toList();
    final humidityValues = devices
        .map((device) => _asDouble(device['humidity']))
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
      'temperature': temperatureValues.isEmpty
          ? 0.0
          : temperatureValues.reduce((a, b) => a + b) /
                temperatureValues.length,
      'humidity': humidityValues.isEmpty
          ? 0.0
          : humidityValues.reduce((a, b) => a + b) / humidityValues.length,
      'deviceCount': deviceIds.length,
      'deviceIds': deviceIds,
      'deviceId': deviceIds.isEmpty ? '' : deviceIds.first,
      'devices': devices,
      'deviceStatus': _worstStatus(
        devices.map((d) => (d['deviceStatus'] ?? 'OK').toString()).toList(),
      ),
    };
  }

  String _worstStatus(List<String> statuses) {
    if (statuses.contains('ERROR')) return 'ERROR';
    if (statuses.contains('WARNING')) return 'WARNING';
    return 'OK';
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
      'motion': device['motion_active'] == true || device['motion'] == true,
      'online': device['connected'] != false,
      'brightness': _asDouble(device['brightness']),
      'batteryPercent': _asInt(device['batteryPercent'] ?? device['battery']),
      'lux': _asInt(device['lux']),
      'temperature': _asDouble(device['temperature']),
      'humidity': _asDouble(device['humidity']),
      'deviceStatus': (device['deviceStatus'] ?? 'OK').toString(),
      'nightGuardEnabled': device['nightGuardEnabled'] == true,
      'nightGuardStartHour': device['nightGuardStartHour'] != null ? _asInt(device['nightGuardStartHour']) : 22,
      'nightGuardStartMinute': _asInt(device['nightGuardStartMinute']),
      'nightGuardEndHour': device['nightGuardEndHour'] != null ? _asInt(device['nightGuardEndHour']) : 6,
      'nightGuardEndMinute': _asInt(device['nightGuardEndMinute']),
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
                    if (_showOfflineSnapshotNotice) ...[
                      const SizedBox(height: 12),
                      _offlineSnapshotBanner(),
                    ],
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
                    border: Border.all(color: _screenBg(context), width: 1.5),
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
    final anyOn = _anyOn;
    final targetOn = canControlAll ? !anyOn : false;
    final isDark = _isDark(context);
    final active = anyOn && canControlAll;

    return GestureDetector(
      onTap: !canControlAll || _powerLoading
          ? null
          : () => _setAllPower(targetOn),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [
                    Color(0xFFFFC44D),
                    Color(0xFFF7931A),
                    Color(0xFFE07A0E),
                  ],
                  stops: [0.0, 0.55, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : _cardColor(context),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: active ? Colors.transparent : _borderColor(context),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF9F43).withValues(alpha: .5),
                    blurRadius: 36,
                    spreadRadius: 2,
                    offset: const Offset(0, 14),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? .22 : .06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: active
                    ? Colors.black.withValues(alpha: .12)
                    : (isDark ? Colors.white10 : const Color(0xFFF2F4F8)),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                active ? '☀️' : '🌙',
                style: const TextStyle(fontSize: 30),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !canControlAll
                        ? 'Включить всё'
                        : anyOn
                        ? 'Выключить всё'
                        : 'Включить всё',
                    style: TextStyle(
                      color: active
                          ? const Color(0xFF1A0F00)
                          : _textColor(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    !canControlAll
                        ? 'Добавьте первую панель'
                        : anyOn
                        ? 'Освещение включено'
                        : 'Освещение выключено',
                    style: TextStyle(
                      color: active
                          ? const Color(0xFF1A0F00).withValues(alpha: .65)
                          : _mutedColor(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            _powerLoading
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: active ? const Color(0xFF1A0F00) : _accent,
                    ),
                  )
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.black.withValues(alpha: .15)
                          : (isDark ? Colors.white12 : const Color(0xFFF2F4F8)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      color: active
                          ? const Color(0xFF1A0F00)
                          : _textColor(context),
                      size: 24,
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

  Widget _offlineSnapshotBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _accent.withValues(alpha: _isDark(context) ? .45 : .7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.wifi_off_rounded, color: _accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Нет интернета. Показаны последние сохранённые данные.',
              style: TextStyle(
                color: _textColor(context),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
    final cardId = card['id']?.toString() ?? '';
    final cardWidget = _ZoneCard(
      card: card,
      key: card['kind'] == 'zone' && cardId.isNotEmpty
          ? _zoneCardKey(cardId)
          : null,
      isDark: _isDark(context),
      powerLoading: _powerLoading,
      onTap: () => _openCard(card),
      onToggle: () => _toggleCard(card['id']?.toString() ?? ''),
    );

    if (card['kind'] == 'zone') {
      return DragTarget<_DraggedDevicePayload>(
        onWillAcceptWithDetails: (details) {
          final zoneId = card['zoneId']?.toString().trim() ?? '';
          return zoneId.isNotEmpty && details.data.deviceId.trim().isNotEmpty;
        },
        onAcceptWithDetails: (details) async {
          final confirmed = await _confirmDeviceMove(
            deviceName: details.data.name,
            targetName: (card['name'] ?? 'зона').toString(),
          );
          if (!confirmed || !mounted) return;
          await _moveDeviceToZone(details.data, card);
        },
        builder: (context, candidateData, rejectedData) {
          return _ZoneCard(
            card: card,
            key: cardId.isNotEmpty ? _zoneCardKey(cardId) : null,
            isDark: _isDark(context),
            powerLoading: _powerLoading,
            dropHighlighted:
                candidateData.isNotEmpty || _snapZoneCardId == cardId,
            isDraggingGlobal: _isDragging,
            onTap: () => _openCard(card),
            onToggle: () => _toggleCard(card['id']?.toString() ?? ''),
          );
        },
      );
    }

    if (card['kind'] == 'device') {
      final payload = _DraggedDevicePayload(
        deviceId: card['deviceId']?.toString() ?? '',
        name: card['name']?.toString() ?? 'Панель',
      );

      return LongPressDraggable<_DraggedDevicePayload>(
        data: payload,
        maxSimultaneousDrags: 1,
        rootOverlay: true,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: () {
          HapticService.light();
          _lastDragGlobalPosition = null;
          if (mounted) {
            setState(() {
              _snapZoneCardId = null;
              _isDragging = true;
            });
          }
        },
        onDragUpdate: (details) => _updateSnapZone(details.globalPosition),
        onDragEnd: (details) {
          if (mounted) setState(() => _isDragging = false);
          _handleDragEnd(payload, details.wasAccepted);
        },
        feedback: Material(
          color: Colors.transparent,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: -0.05,
              child: SizedBox(
                width: 170,
                height: 250,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 44,
                        spreadRadius: 8,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: _ZoneCard(
                    card: card,
                    isDark: _isDark(context),
                    powerLoading: true,
                    dragging: true,
                    onTap: () {},
                    onToggle: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.28,
          child: IgnorePointer(child: cardWidget),
        ),
        child: cardWidget,
      );
    }

    return cardWidget;
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
  final bool dropHighlighted;
  final bool dragging;
  final bool isDraggingGlobal;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _ZoneCard({
    super.key,
    required this.card,
    required this.isDark,
    required this.powerLoading,
    this.dropHighlighted = false,
    this.dragging = false,
    this.isDraggingGlobal = false,
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

    final textColor = isDark
        ? const Color(0xFFF5F5F7)
        : const Color(0xFF1C1C1E);
    final mutedColor = isDark
        ? const Color(0xFF6E6E75)
        : const Color(0xFF8E8E93);
    final cardBg = isDark ? const Color(0xFF17171B) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF26262D)
        : const Color(0xFFE5E5EA);

    final isZoneCard = card['kind'] == 'zone';
    final deviceCount = _asInt(card['deviceCount']);
    final rawBrightness = _asDouble(card['brightness']);
    final brightness = (rawBrightness > 100
            ? rawBrightness / 255 * 100
            : rawBrightness)
        .round();
    final lux = _asInt(card['lux']);
    final battery = _asInt(card['batteryPercent']);
    final motion = card['motion'] == true;
    final online = card['online'] != false;
    final deviceStatus = (card['deviceStatus'] ?? 'OK').toString();
    final isDropTargetActive = widget.dropHighlighted && isZoneCard;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: widget.dragging
            ? 1.04
            : isDropTargetActive
            ? 1.06
            : widget.isDraggingGlobal && isZoneCard
            ? 1.02
            : _pressed
            ? 0.94
            : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                  color: isDropTargetActive
                      ? _accent
                      : widget.isDraggingGlobal && isZoneCard
                      ? _accent.withValues(alpha: 0.5)
                      : on
                      ? color.withValues(alpha: .4)
                      : borderColor,
                  width: isDropTargetActive
                      ? 2.2
                      : widget.isDraggingGlobal && isZoneCard
                      ? 1.6
                      : 1.2,
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
                          color: Colors.black.withValues(
                            alpha: isDark ? .18 : .04,
                          ),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                        if (isDropTargetActive)
                          BoxShadow(
                            color: _accent.withValues(alpha: .36),
                            blurRadius: 32,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        if (widget.isDraggingGlobal &&
                            isZoneCard &&
                            !isDropTargetActive)
                          BoxShadow(
                            color: _accent.withValues(alpha: .15),
                            blurRadius: 16,
                            spreadRadius: 0,
                            offset: const Offset(0, 4),
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
                      Flexible(
                        child: _Dot(
                          color: online
                              ? const Color(0xFF30D158)
                              : Colors.redAccent,
                          label: online ? 'Online' : 'Offline',
                          mutedColor: mutedColor,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: _Dot(
                          color: motion ? const Color(0xFFFFD54F) : mutedColor,
                          label: motion ? 'Движ.' : 'Тихо',
                          mutedColor: mutedColor,
                          isDark: isDark,
                        ),
                      ),
                      const Spacer(),
                      _StatusBadge(status: deviceStatus),
                    ],
                  ),
                ],
              ),
            ),
            if (isDropTargetActive)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: _accent.withValues(alpha: 0.08),
                  ),
                ),
              ),
            if (isDropTargetActive)
              Positioned.fill(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.black,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Отпустите',
                        style: TextStyle(
                          color: _accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DraggedDevicePayload {
  final String deviceId;
  final String name;

  const _DraggedDevicePayload({required this.deviceId, required this.name});
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

// ── Device status badge (OK / WARNING / ERROR) ──────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    switch (status) {
      case 'ERROR':
        bg = const Color(0xFFFF3B30).withValues(alpha: 0.15);
        fg = const Color(0xFFFF3B30);
        label = 'ERROR';
        break;
      case 'WARNING':
        bg = const Color(0xFFFFCC00).withValues(alpha: 0.18);
        fg = const Color(0xFFFFCC00);
        label = 'WARN';
        break;
      default:
        bg = const Color(0xFF30D158).withValues(alpha: 0.14);
        fg = const Color(0xFF30D158);
        label = 'OK';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
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
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mutedColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
