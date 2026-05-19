import 'dart:async';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/app_settings_service.dart';
import 'package:sunmind_thebest/core/services/offline_snapshot_service.dart';
import 'package:sunmind_thebest/core/services/view_cache_service.dart';
import 'package:sunmind_thebest/core/theme/app_theme.dart';
import 'package:sunmind_thebest/models/analytics_summary.dart';
import 'package:sunmind_thebest/models/telemetry_point.dart';

const _accent = kA2;
const _card = Color(0xFF17171B);
const _bg = Color(0xFF0B0B0D);
const _muted = Color(0xFF6E6E75);
const _border = Color(0xFF26262D);

const _zoneColors = <Color>[
  Color(0xFFFFD54F),
  Color(0xFF42A5F5),
  Color(0xFF26C6DA),
  Color(0xFFAB47BC),
  Color(0xFF4CAF50),
  Color(0xFFFF7043),
];

class _ZoneShare {
  final String name;
  final Color color;
  final double percent;
  const _ZoneShare({
    required this.name,
    required this.color,
    required this.percent,
  });
}

class _EventItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  const _EventItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final ApiService _api = ApiService();
  final AppSettingsService _settings = AppSettingsService();

  String period = 'day';
  bool loading = true;
  String? error;
  bool showOfflineSnapshotNotice = false;

  double totalKwh = 0;
  double avgSavings = 0;
  int totalMotionCount = 0;
  double lightOnHours = 0;
  double? remainingEnergyWh;
  double? remainingHours;
  int? latestBatteryPercent;
  double _tariff = AppSettingsService.defaultTariff;
  double _costSom = 0;

  List<double> consumptionByBucket = [];
  List<double> motionByBucket = [];
  List<double> batteryByBucket = [];
  List<double> acByBucket = [];
  List<double> batterySourceByBucket = [];
  List<String> bucketLabels = [];

  List<_ZoneShare> zoneShares = [];
  List<_EventItem> events = [];

  List<Map<String, dynamic>> _devices = [];

  Timer? _midnightTimer;
  // Stores the calendar date of the last 'day' load (year/month/day only)
  DateTime _lastDayLoadDate = DateTime(0);

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _initialize();
    _scheduleMidnightReset();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  /// Schedules a timer that fires exactly at the next midnight and resets
  /// the "today" analytics automatically.
  void _scheduleMidnightReset() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);
    _midnightTimer = Timer(delay, () {
      if (!mounted) return;
      _invalidateDayCache();
      if (period == 'day') {
        _clearViewData();
        _load(showLoading: true);
      }
      // Re-schedule for the following midnight
      _scheduleMidnightReset();
    });
  }

  /// Removes the 'day' period from all caches so the next load fetches fresh.
  void _invalidateDayCache() {
    ViewCacheService.analyticsByPeriod.remove('day');
    _lastDayLoadDate = DateTime(0);
  }

  Future<void> _initialize() async {
    _checkDayChanged();
    final restored = _restoreCache() || await _restorePersistedCache();
    if (!mounted) return;
    await _load(showLoading: !restored);
  }

  /// If the calendar date has changed since the last 'day' load, drop the cache.
  void _checkDayChanged() {
    if (period != 'day') return;
    final today = _today;
    if (_lastDayLoadDate.isBefore(today)) {
      _invalidateDayCache();
    }
  }

  bool get _hasCachedData =>
      bucketLabels.isNotEmpty ||
      consumptionByBucket.isNotEmpty ||
      motionByBucket.isNotEmpty ||
      zoneShares.isNotEmpty ||
      events.isNotEmpty;

  bool _restoreCache() {
    final cached = ViewCacheService.analyticsByPeriod[period];
    if (cached == null) return false;

    totalKwh = cached.totalKwh;
    avgSavings = cached.avgSavings;
    totalMotionCount = cached.totalMotionCount;
    lightOnHours = cached.lightOnHours;
    remainingEnergyWh = cached.remainingEnergyWh;
    remainingHours = cached.remainingHours;
    latestBatteryPercent = cached.latestBatteryPercent;
    _tariff = cached.tariff;
    _costSom = cached.costSom;
    consumptionByBucket = List<double>.from(cached.consumptionByBucket);
    motionByBucket = List<double>.from(cached.motionByBucket);
    batteryByBucket = List<double>.from(cached.batteryByBucket);
    acByBucket = List<double>.from(cached.acByBucket);
    batterySourceByBucket = List<double>.from(cached.batterySourceByBucket);
    bucketLabels = List<String>.from(cached.bucketLabels);
    zoneShares = cached.zoneShares
        .map(
          (entry) => _ZoneShare(
            name: (entry['name'] ?? '').toString(),
            color: entry['color'] as Color? ?? _zoneColors.first,
            percent: (entry['percent'] as num?)?.toDouble() ?? 0,
          ),
        )
        .toList();
    events = cached.events
        .map(
          (entry) => _EventItem(
            icon: entry['icon'] as IconData? ?? Icons.info_outline_rounded,
            color: entry['color'] as Color? ?? Colors.white54,
            title: (entry['title'] ?? '').toString(),
            subtitle: (entry['subtitle'] ?? '').toString(),
            time: (entry['time'] ?? '').toString(),
          ),
        )
        .toList();
    _devices = cached.devices
        .map((device) => Map<String, dynamic>.from(device))
        .toList();
    loading = false;
    showOfflineSnapshotNotice = false;
    return true;
  }

  Future<bool> _restorePersistedCache() async {
    final cached = await OfflineSnapshotService.loadAnalyticsSnapshot(period);
    if (cached == null) return false;

    totalKwh = (cached['totalKwh'] as num?)?.toDouble() ?? 0;
    avgSavings = (cached['avgSavings'] as num?)?.toDouble() ?? 0;
    totalMotionCount = (cached['totalMotionCount'] as num?)?.toInt() ?? 0;
    lightOnHours = (cached['lightOnHours'] as num?)?.toDouble() ?? 0;
    remainingEnergyWh = (cached['remainingEnergyWh'] as num?)?.toDouble();
    remainingHours = (cached['remainingHours'] as num?)?.toDouble();
    latestBatteryPercent = (cached['latestBatteryPercent'] as num?)?.toInt();
    _tariff = (cached['tariff'] as num?)?.toDouble() ?? _tariff;
    _costSom = (cached['costSom'] as num?)?.toDouble() ?? 0;
    consumptionByBucket = ((cached['consumptionByBucket'] as List?) ?? const [])
        .map((value) => (value as num).toDouble())
        .toList();
    motionByBucket = ((cached['motionByBucket'] as List?) ?? const [])
        .map((value) => (value as num).toDouble())
        .toList();
    batteryByBucket = ((cached['batteryByBucket'] as List?) ?? const [])
        .map((value) => (value as num).toDouble())
        .toList();
    acByBucket = ((cached['acByBucket'] as List?) ?? const [])
        .map((value) => (value as num).toDouble())
        .toList();
    batterySourceByBucket =
        ((cached['batterySourceByBucket'] as List?) ?? const [])
            .map((value) => (value as num).toDouble())
            .toList();
    bucketLabels = ((cached['bucketLabels'] as List?) ?? const [])
        .map((value) => value.toString())
        .toList();

    final rawZoneShares = (cached['zoneShares'] as List?) ?? const [];
    zoneShares = rawZoneShares.whereType<Map>().toList().asMap().entries.map((
      entry,
    ) {
      final value = entry.value;
      return _ZoneShare(
        name: (value['name'] ?? '').toString(),
        color: _zoneColors[entry.key % _zoneColors.length],
        percent: (value['percent'] as num?)?.toDouble() ?? 0,
      );
    }).toList();

    final rawEvents = (cached['events'] as List?) ?? const [];
    events = rawEvents.whereType<Map>().map((value) {
      final iconCodePoint =
          (value['iconCodePoint'] as num?)?.toInt() ??
          Icons.info_outline_rounded.codePoint;
      return _EventItem(
        icon: IconData(
          iconCodePoint,
          fontFamily: (value['iconFontFamily'] ?? 'MaterialIcons').toString(),
          fontPackage: value['iconFontPackage']?.toString(),
          matchTextDirection: value['iconMatchTextDirection'] == true,
        ),
        color: Color(
          (value['color'] as num?)?.toInt() ?? Colors.white54.toARGB32(),
        ),
        title: (value['title'] ?? '').toString(),
        subtitle: (value['subtitle'] ?? '').toString(),
        time: (value['time'] ?? '').toString(),
      );
    }).toList();

    _devices = ((cached['devices'] as List?) ?? const [])
        .whereType<Map>()
        .map((device) => Map<String, dynamic>.from(device))
        .toList();
    loading = false;
    return true;
  }

  void _clearViewData() {
    totalKwh = 0;
    avgSavings = 0;
    totalMotionCount = 0;
    lightOnHours = 0;
    remainingEnergyWh = null;
    remainingHours = null;
    latestBatteryPercent = null;
    _costSom = 0;
    consumptionByBucket = [];
    motionByBucket = [];
    batteryByBucket = [];
    acByBucket = [];
    batterySourceByBucket = [];
    bucketLabels = [];
    zoneShares = [];
    events = [];
    _devices = [];
  }

  void _saveCache() {
    ViewCacheService.analyticsByPeriod[period] = AnalyticsViewCache(
      period: period,
      totalKwh: totalKwh,
      avgSavings: avgSavings,
      totalMotionCount: totalMotionCount,
      lightOnHours: lightOnHours,
      remainingEnergyWh: remainingEnergyWh,
      remainingHours: remainingHours,
      latestBatteryPercent: latestBatteryPercent,
      tariff: _tariff,
      costSom: _costSom,
      consumptionByBucket: List<double>.from(consumptionByBucket),
      motionByBucket: List<double>.from(motionByBucket),
      batteryByBucket: List<double>.from(batteryByBucket),
      acByBucket: List<double>.from(acByBucket),
      batterySourceByBucket: List<double>.from(batterySourceByBucket),
      bucketLabels: List<String>.from(bucketLabels),
      zoneShares: zoneShares
          .map(
            (share) => <String, dynamic>{
              'name': share.name,
              'color': share.color,
              'percent': share.percent,
            },
          )
          .toList(),
      events: events
          .map(
            (event) => <String, dynamic>{
              'icon': event.icon,
              'color': event.color,
              'title': event.title,
              'subtitle': event.subtitle,
              'time': event.time,
            },
          )
          .toList(),
      devices: _devices
          .map((device) => Map<String, dynamic>.from(device))
          .toList(),
    );
    OfflineSnapshotService.saveAnalyticsSnapshot(period, {
      'totalKwh': totalKwh,
      'avgSavings': avgSavings,
      'totalMotionCount': totalMotionCount,
      'lightOnHours': lightOnHours,
      'remainingEnergyWh': remainingEnergyWh,
      'remainingHours': remainingHours,
      'latestBatteryPercent': latestBatteryPercent,
      'tariff': _tariff,
      'costSom': _costSom,
      'consumptionByBucket': consumptionByBucket,
      'motionByBucket': motionByBucket,
      'batteryByBucket': batteryByBucket,
      'acByBucket': acByBucket,
      'batterySourceByBucket': batterySourceByBucket,
      'bucketLabels': bucketLabels,
      'zoneShares': zoneShares
          .map((share) => {'name': share.name, 'percent': share.percent})
          .toList(),
      'events': events
          .map(
            (event) => {
              'iconCodePoint': event.icon.codePoint,
              'iconFontFamily': event.icon.fontFamily,
              'iconFontPackage': event.icon.fontPackage,
              'iconMatchTextDirection': event.icon.matchTextDirection,
              'color': event.color.toARGB32(),
              'title': event.title,
              'subtitle': event.subtitle,
              'time': event.time,
            },
          )
          .toList(),
      'devices': _devices
          .map((device) => Map<String, dynamic>.from(device))
          .toList(),
    });
  }

  Future<void> _load({bool showLoading = true}) async {
    if (!mounted) return;
    // Invalidate 'day' cache if a new calendar day has started
    _checkDayChanged();
    if (period == 'day') {
      _lastDayLoadDate = _today;
    }
    if (showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    } else if (error != null) {
      setState(() => error = null);
    }
    try {
      _tariff = await _settings.getElectricityTariff();
      final devicesRaw = await _api.getDevices();
      _devices = devicesRaw;

      if (_devices.isEmpty) {
        if (mounted) {
          setState(() {
            loading = false;
            error = 'Нет устройств. Добавьте панель.';
          });
        }
        return;
      }

      final ids = _devices.map((d) => d['deviceId'] as String).toList();

      final analyticsList = await Future.wait(
        ids.map(
          (id) => _api
              .getAnalyticsSummary(id, period: period)
              .then(AnalyticsSummary.fromJson)
              .catchError((_) => AnalyticsSummary.fromJson({})),
        ),
      );

      final telemetryList = await Future.wait(
        ids.map(
          (id) => _api
              .getTelemetry(id, period: period)
              .then((rows) => rows.map(TelemetryPoint.fromJson).toList())
              .catchError((_) => <TelemetryPoint>[]),
        ),
      );

      double kwh = 0;
      double savingsSum = 0;
      int savingsCount = 0;
      int motionTotal = 0;
      double hoursOn = 0;

      for (int i = 0; i < _devices.length; i++) {
        final s = analyticsList[i];
        kwh += s.energyKwh;
        motionTotal += s.motionCount;
        if (s.estimatedSavingsPercent > 0) {
          savingsSum += s.estimatedSavingsPercent;
          savingsCount++;
        }
        hoursOn += s.lightOnMinutes / 60.0;
      }

      totalKwh = kwh;
      avgSavings = savingsCount > 0 ? savingsSum / savingsCount : 0;
      totalMotionCount = motionTotal;
      lightOnHours = hoursOn;

      double? remWh;
      double? remH;
      int? batPct;
      for (final s in analyticsList) {
        if (s.remainingEnergyWh != null) {
          remWh = (remWh ?? 0) + s.remainingEnergyWh!;
          remH = (remH ?? 0) + (s.remainingHours ?? 0);
          batPct = s.batteryMax;
        }
      }
      remainingEnergyWh = remWh;
      remainingHours = remH;
      latestBatteryPercent = batPct;
      _costSom = kwh * _tariff;

      final combined = telemetryList.expand((t) => t).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      _buildChart(combined);
      _buildZones(analyticsList);
      _buildEvents(combined);
      showOfflineSnapshotNotice = false;
      _saveCache();

      if (mounted && showLoading) {
        setState(() => loading = false);
      } else if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          if (ApiService.isOfflineError(e) && _hasCachedData) {
            error = null;
            showOfflineSnapshotNotice = true;
          } else if (ApiService.isOfflineError(e)) {
            error =
                'Нет интернета. Подключитесь к сети, чтобы загрузить аналитику.';
          } else {
            error = e.toString();
          }
        });
      }
    }
  }

  String _bucketKey(DateTime dt, List<String> labels) {
    if (period == 'day') return dt.toLocal().hour.toString().padLeft(2, '0');
    if (period == 'week') return labels[(dt.toLocal().weekday - 1) % 7];
    return 'Нед ${((dt.toLocal().day - 1) ~/ 7).clamp(0, 3) + 1}';
  }

  void _buildChart(List<TelemetryPoint> points) {
    final List<String> labels;
    if (period == 'day') {
      labels = List.generate(24, (h) => h.toString().padLeft(2, '0'));
    } else if (period == 'week') {
      labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    } else {
      labels = ['Нед 1', 'Нед 2', 'Нед 3', 'Нед 4'];
    }

    final Map<String, double> energyB = {for (final l in labels) l: 0.0};
    final Map<String, double> motionB = {for (final l in labels) l: 0.0};
    final Map<String, double> batterySum = {for (final l in labels) l: 0.0};
    final Map<String, int> batteryCount = {for (final l in labels) l: 0};
    final Map<String, double> acCount = {for (final l in labels) l: 0.0};
    final Map<String, double> batterySourceCount = {
      for (final l in labels) l: 0.0,
    };

    bool prevMotion = false;
    for (int i = 0; i < points.length; i++) {
      final curr = points[i];
      final key = _bucketKey(curr.createdAt, labels);

      // Motion events (rising edge)
      if (curr.motion && !prevMotion && motionB.containsKey(key)) {
        motionB[key] = motionB[key]! + 1;
      }
      prevMotion = curr.motion;

      // Battery avg per bucket
      if (curr.batteryPercent > 0 && batterySum.containsKey(key)) {
        batterySum[key] = batterySum[key]! + curr.batteryPercent;
        batteryCount[key] = batteryCount[key]! + 1;
      }

      // Power source counts per bucket
      if (acCount.containsKey(key)) {
        if (curr.powerSource == 'ac') {
          acCount[key] = acCount[key]! + 1;
        } else {
          batterySourceCount[key] = batterySourceCount[key]! + 1;
        }
      }

      // Energy
      if (i + 1 < points.length) {
        final next = points[i + 1];
        final deltaMs = next.createdAt
            .difference(curr.createdAt)
            .inMilliseconds;
        if (deltaMs > 0 && deltaMs <= 3600000 && energyB.containsKey(key)) {
          const powerW = 40.0;
          energyB[key] =
              energyB[key]! +
              powerW * (curr.brightness / 255.0) * (deltaMs / 3600000) / 1000;
        }
      }
    }

    consumptionByBucket = labels.map((l) => energyB[l]!).toList();
    motionByBucket = labels.map((l) => motionB[l]!).toList();
    batteryByBucket = labels.map((l) {
      final cnt = batteryCount[l]!;
      return cnt > 0 ? batterySum[l]! / cnt : 0.0;
    }).toList();
    acByBucket = labels.map((l) => acCount[l]!).toList();
    batterySourceByBucket = labels.map((l) => batterySourceCount[l]!).toList();
    bucketLabels = labels;
  }

  void _buildZones(List<AnalyticsSummary> analyticsList) {
    final Map<String, double> zoneMap = {};
    for (int i = 0; i < _devices.length; i++) {
      final zoneName = (_devices[i]['zoneName'] as String?)?.trim();
      final name = (zoneName != null && zoneName.isNotEmpty)
          ? zoneName
          : 'Прочие';
      zoneMap[name] = (zoneMap[name] ?? 0) + analyticsList[i].energyKwh;
    }
    final totalZ = zoneMap.values.fold(0.0, (a, b) => a + b);
    final sorted = zoneMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    zoneShares = sorted.asMap().entries.map((e) {
      final pct = totalZ > 0 ? e.value.value / totalZ * 100 : 0.0;
      return _ZoneShare(
        name: e.value.key,
        color: _zoneColors[e.key % _zoneColors.length],
        percent: pct,
      );
    }).toList();
  }

  void _buildEvents(List<TelemetryPoint> points) {
    final evts = <_EventItem>[];
    bool prevMotion = false;
    bool prevManual = false;

    for (final p in points.reversed) {
      if (evts.length >= 8) break;

      final deviceEntry = _devices
          .where((d) => d['deviceId'] == p.deviceId)
          .firstOrNull;
      final zoneName = (deviceEntry?['zoneName'] as String?)?.trim();
      final label = (zoneName != null && zoneName.isNotEmpty)
          ? zoneName
          : p.deviceId;

      if (!prevMotion && p.motion) {
        evts.add(
          _EventItem(
            icon: Icons.visibility_rounded,
            color: Colors.orange,
            title: 'Датчик движения',
            subtitle: '$label — авто-включение',
            time: _timeStr(p.createdAt),
          ),
        );
      }
      if (p.manualMode != prevManual) {
        evts.add(
          _EventItem(
            icon: p.manualMode
                ? Icons.pan_tool_rounded
                : Icons.smart_toy_rounded,
            color: p.manualMode ? Colors.purpleAccent : const Color(0xFF26C6DA),
            title: p.manualMode ? 'Ручное изменение' : 'Авто-режим',
            subtitle: p.manualMode
                ? '$label — ${(p.brightness / 255 * 100).round()}%'
                : '$label — авто',
            time: _timeStr(p.createdAt),
          ),
        );
      }
      prevMotion = p.motion;
      prevManual = p.manualMode;
    }

    events = evts;
  }

  String _timeStr(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _bg : const Color(0xFFF6F7FB);
    final cardColor = isDark ? _card : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? _muted : const Color(0xFF6D7481);
    final borderColor = isDark ? _border : const Color(0xFFE2E6EF);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Аналитика'),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: _accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            32 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Hero summary card
              if (!loading && error == null)
                _HeroSummaryCard(
                  totalKwh: totalKwh,
                  avgSavings: avgSavings,
                  period: period,
                ),
              if (!loading && error == null) const SizedBox(height: 16),
              _PeriodTabs(
                period: period,
                cardColor: cardColor,
                textColor: textColor,
                onChanged: (p) {
                  final previousPeriod = period;
                  setState(() {
                    period = p;
                    final restored = _restoreCache();
                    if (!restored) {
                      period = p;
                      _clearViewData();
                      loading = true;
                      showOfflineSnapshotNotice = false;
                    }
                  });
                  if (previousPeriod == p) return;
                  _load(showLoading: !_hasCachedData);
                },
              ),
              const SizedBox(height: 20),
              if (showOfflineSnapshotNotice) ...[
                _OfflineSnapshotBanner(
                  cardColor: cardColor,
                  textColor: textColor,
                ),
                const SizedBox(height: 16),
              ],
              if (loading)
                SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
                )
              else if (error != null)
                _ErrorBox(
                  message: error!,
                  onRetry: _load,
                  cardColor: cardColor,
                  textColor: textColor,
                )
              else ...[
                _StatsGrid(
                  totalKwh: totalKwh,
                  avgSavings: avgSavings,
                  motionCount: totalMotionCount,
                  lightOnHours: lightOnHours,
                  costSom: _costSom,
                  tariff: _tariff,
                  batteryPercent: latestBatteryPercent,
                  remainingHours: remainingHours,
                  cardColor: cardColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                const SizedBox(height: 16),
                _ConsumptionChart(
                  data: consumptionByBucket,
                  labels: bucketLabels,
                  period: period,
                  cardColor: cardColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _MotionChart(
                  data: motionByBucket,
                  labels: bucketLabels,
                  period: period,
                  cardColor: cardColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                  isDark: isDark,
                ),
                if (batteryByBucket.any((v) => v > 0)) ...[
                  const SizedBox(height: 16),
                  _BatteryChart(
                    data: batteryByBucket,
                    labels: bucketLabels,
                    cardColor: cardColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                    isDark: isDark,
                  ),
                ],
                if (acByBucket.any((v) => v > 0) ||
                    batterySourceByBucket.any((v) => v > 0)) ...[
                  const SizedBox(height: 16),
                  _PowerSourceCard(
                    acByBucket: acByBucket,
                    batterySourceByBucket: batterySourceByBucket,
                    bucketLabels: bucketLabels,
                    period: period,
                    cardColor: cardColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ],
                const SizedBox(height: 16),
                if (zoneShares.isNotEmpty) ...[
                  _ZoneBreakdown(
                    shares: zoneShares,
                    cardColor: cardColor,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                  const SizedBox(height: 16),
                ],
                _EventsList(
                  events: events,
                  cardColor: cardColor,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
                const SizedBox(height: 16),
                if (avgSavings > 5)
                  _AiHintCard(
                    savings: avgSavings,
                    isDark: isDark,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Period tabs ──────────────────────────────────────────────────────────────

class _PeriodTabs extends StatelessWidget {
  final String period;
  final Color cardColor;
  final Color textColor;
  final ValueChanged<String> onChanged;

  const _PeriodTabs({
    required this.period,
    required this.cardColor,
    required this.textColor,
    required this.onChanged,
  });

  static const _tabs = [
    ('day', 'Сегодня'),
    ('week', 'Неделя'),
    ('month', 'Месяц'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: _tabs.map(((String, String) tab) {
          final selected = period == tab.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(tab.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? _accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  tab.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.black : textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OfflineSnapshotBanner extends StatelessWidget {
  final Color cardColor;
  final Color textColor;

  const _OfflineSnapshotBanner({
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.7)),
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
                color: textColor,
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
}

// ── Stats grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final double totalKwh;
  final double avgSavings;
  final int motionCount;
  final double lightOnHours;
  final double costSom;
  final double tariff;
  final int? batteryPercent;
  final double? remainingHours;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;

  const _StatsGrid({
    required this.totalKwh,
    required this.avgSavings,
    required this.motionCount,
    required this.lightOnHours,
    required this.costSom,
    required this.tariff,
    required this.batteryPercent,
    required this.remainingHours,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
  });

  Color _batteryColor(int pct) {
    if (pct > 50) return const Color(0xFF2E7D32);
    if (pct > 20) return const Color(0xFF795500);
    return const Color(0xFF7B1F1F);
  }

  @override
  Widget build(BuildContext context) {
    final batPct = batteryPercent ?? 0;
    final remH = remainingHours ?? 0;
    final remLabel = remH >= 1
        ? '${remH.toStringAsFixed(1)} ч'
        : '${(remH * 60).round()} мин';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          label: 'ЭКОНОМИЯ',
          value: '${avgSavings.toStringAsFixed(0)}%',
          badge: avgSavings > 0 ? '+${avgSavings.toStringAsFixed(0)}%' : '0%',
          badgeColor: avgSavings > 0 ? const Color(0xFF2E7D32) : Colors.grey,
          cardColor: cardColor,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
        _StatCard(
          label: 'КВТ·Ч',
          value: totalKwh.toStringAsFixed(2),
          badge: 'кВт·ч',
          badgeColor: const Color(0xFF1A3A5C),
          cardColor: cardColor,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
        _StatCard(
          label: 'ДВИЖЕНИЕ',
          value: motionCount.toString(),
          badge: 'событий',
          badgeColor: const Color(0xFF003838),
          cardColor: cardColor,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
        _StatCard(
          label: 'РАБОТА',
          value: '${lightOnHours.toStringAsFixed(1)}ч',
          badge: 'горит',
          badgeColor: const Color(0xFF003838),
          cardColor: cardColor,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
        _StatCard(
          label: 'СТОИМОСТЬ',
          value: costSom.toStringAsFixed(0),
          badge: 'сом',
          badgeColor: const Color(0xFF4A2800),
          cardColor: cardColor,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
        if (batteryPercent != null)
          _StatCard(
            label: 'БАТАРЕЯ',
            value: '$batPct%',
            badge: remH > 0 ? remLabel : '—',
            badgeColor: _batteryColor(batPct),
            cardColor: cardColor,
            textColor: textColor,
            mutedColor: mutedColor,
          )
        else
          _StatCard(
            label: 'БАТАРЕЯ',
            value: '—',
            badge: 'нет данных',
            badgeColor: Colors.grey.shade800,
            cardColor: cardColor,
            textColor: textColor,
            mutedColor: mutedColor,
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String badge;
  final Color badgeColor;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.badge,
    required this.badgeColor,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Consumption line chart ───────────────────────────────────────────────────

class _ConsumptionChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final String period;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;
  final bool isDark;

  const _ConsumptionChart({
    required this.data,
    required this.labels,
    required this.period,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isNotEmpty ? data.reduce(max) : 1.0;
    final displayMax = maxVal < 0.001 ? 1.0 : maxVal * 1.25;

    // Show fewer labels to avoid crowding
    final step = data.length > 8 ? (data.length / 6).ceil() : 1;

    final spots = <FlSpot>[
      for (int i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
    ];

    // Trend: compare first half vs second half
    double trendPct = 0;
    if (data.length >= 2) {
      final half = data.length ~/ 2;
      final firstHalf = data.take(half).fold(0.0, (a, b) => a + b);
      final secondHalf = data.skip(half).fold(0.0, (a, b) => a + b);
      if (firstHalf > 0) {
        trendPct = (secondHalf - firstHalf) / firstHalf * 100;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Потребление',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'кВт·ч',
                    style: TextStyle(fontSize: 12, color: mutedColor),
                  ),
                ],
              ),
              const Spacer(),
              if (trendPct != 0)
                Text(
                  '${trendPct > 0 ? '↑' : '↘'}${trendPct.abs().toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: trendPct > 0 ? Colors.redAccent : Colors.greenAccent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: displayMax,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => cardColor,
                    getTooltipItems: (spots) => spots
                        .map(
                          (s) => LineTooltipItem(
                            '${s.y.toStringAsFixed(4)} кВт',
                            TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: displayMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE8ECF0),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: step.toDouble(),
                      getTitlesWidget: (value, meta) {
                        final idx = value.round();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx],
                            style: TextStyle(color: mutedColor, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: _accent,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, p2, p3) => FlDotCirclePainter(
                        radius: 3,
                        color: _accent,
                        strokeWidth: 0,
                        strokeColor: Colors.transparent,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          _accent.withValues(alpha: 0.22),
                          _accent.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Motion bar chart ─────────────────────────────────────────────────────────

class _MotionChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final String period;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;

  const _MotionChart({
    required this.data,
    required this.labels,
    required this.period,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isNotEmpty ? data.reduce(max) : 1.0;
    final displayMax = maxVal < 1 ? 5.0 : maxVal * 1.3;
    final step = period == 'day'
        ? 4
        : data.length > 8
        ? (data.length / 6).ceil()
        : 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активность людей',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          Text(
            'срабатываний датчика',
            style: TextStyle(fontSize: 12, color: mutedColor),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: displayMax,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => cardColor,
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${rod.toY.round()} раз',
                      TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: displayMax / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE8ECF0),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: step.toDouble(),
                      getTitlesWidget: (value, _) {
                        final idx = value.round();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        if (period == 'day' && idx % 4 != 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx],
                            style: TextStyle(color: mutedColor, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: data.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: Colors.orangeAccent,
                        width: data.length > 12 ? 6 : 12,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Battery line chart ────────────────────────────────────────────────────────

class _BatteryChart extends StatelessWidget {
  final List<double> data;
  final List<String> labels;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;

  const _BatteryChart({
    required this.data,
    required this.labels,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
  });

  static Color _batteryColor(double pct) {
    if (pct < 30) return const Color(0xFFEF5350);
    if (pct < 60) return const Color(0xFFFFD54F);
    return const Color(0xFF4CAF50);
  }

  @override
  Widget build(BuildContext context) {
    final step = data.length > 8 ? (data.length / 6).ceil() : 1;
    final nonZero = data.where((v) => v > 0);
    final avgPct = nonZero.isNotEmpty
        ? nonZero.fold(0.0, (s, v) => s + v) / nonZero.length
        : 0.0;
    final lineColor = _batteryColor(avgPct);

    final spots = <FlSpot>[
      for (int i = 0; i < data.length; i++)
        if (data[i] > 0) FlSpot(i.toDouble(), data[i]),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Заряд батареи',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          Text('%', style: TextStyle(fontSize: 12, color: mutedColor)),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => cardColor,
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map(
                          (s) => LineTooltipItem(
                            '${s.y.round()}%',
                            TextStyle(
                              color: _batteryColor(s.y),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE8ECF0),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: step.toDouble(),
                      getTitlesWidget: (value, _) {
                        final idx = value.round();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            labels[idx],
                            style: TextStyle(color: mutedColor, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: lineColor,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          lineColor.withValues(alpha: 0.2),
                          lineColor.withValues(alpha: 0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Power source card ─────────────────────────────────────────────────────────

class _PowerSourceCard extends StatelessWidget {
  final List<double> acByBucket;
  final List<double> batterySourceByBucket;
  final List<String> bucketLabels;
  final String period;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;

  const _PowerSourceCard({
    required this.acByBucket,
    required this.batterySourceByBucket,
    required this.bucketLabels,
    required this.period,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final totalAc = acByBucket.fold(0.0, (s, v) => s + v);
    final totalBat = batterySourceByBucket.fold(0.0, (s, v) => s + v);
    final total = totalAc + totalBat;
    final acPct = total > 0 ? totalAc / total : 0.0;
    final batPct = total > 0 ? totalBat / total : 0.0;

    const acColor = Color(0xFF42A5F5);
    const batColor = Color(0xFFFFD54F);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Источник питания',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          Text(
            'Розетка vs аккумулятор',
            style: TextStyle(fontSize: 12, color: mutedColor),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Donut chart
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 34,
                    sections: [
                      PieChartSectionData(
                        value: acPct,
                        color: acColor,
                        radius: 24,
                        title: '',
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: batPct,
                        color: batColor,
                        radius: 24,
                        title: '',
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PowerSourceLegendRow(
                      color: acColor,
                      label: 'Розетка',
                      percent: acPct * 100,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                    const SizedBox(height: 14),
                    _PowerSourceLegendRow(
                      color: batColor,
                      label: 'Аккумулятор',
                      percent: batPct * 100,
                      textColor: textColor,
                      mutedColor: mutedColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PowerSourceLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double percent;

  final Color textColor;
  final Color mutedColor;

  const _PowerSourceLegendRow({
    required this.color,
    required this.label,
    required this.percent,

    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}% времени',
                style: TextStyle(fontSize: 11, color: mutedColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Zone breakdown (donut) ───────────────────────────────────────────────────

class _ZoneBreakdown extends StatefulWidget {
  final List<_ZoneShare> shares;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;

  const _ZoneBreakdown({
    required this.shares,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  State<_ZoneBreakdown> createState() => _ZoneBreakdownState();
}

class _ZoneBreakdownState extends State<_ZoneBreakdown> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final sections = widget.shares.asMap().entries.map((e) {
      final isTouched = e.key == touchedIndex;
      return PieChartSectionData(
        value: e.value.percent,
        color: e.value.color,
        radius: isTouched ? 54 : 46,
        title: '',
        showTitle: false,
      );
    }).toList();

    final total = widget.shares.fold(0.0, (s, z) => s + z.percent);

    final bool manyZones = widget.shares.length > 3;

    Widget legend = manyZones
        ? Wrap(
            spacing: 12,
            runSpacing: 8,
            children: widget.shares.map((z) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: z.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Text(
                      z.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: widget.textColor, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${z.percent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: widget.textColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }).toList(),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.shares.map((z) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: z.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        z.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: widget.textColor, fontSize: 13),
                      ),
                    ),
                    Text(
                      '${z.percent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: widget.textColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'По комнатам',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: widget.textColor,
            ),
          ),
          const SizedBox(height: 16),
          if (manyZones) ...[
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 34,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              touchedIndex =
                                  response
                                      ?.touchedSection
                                      ?.touchedSectionIndex ??
                                  -1;
                            });
                          },
                        ),
                      ),
                    ),
                    Text(
                      '${total.round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            legend,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: sections,
                          centerSpaceRadius: 32,
                          sectionsSpace: 2,
                          pieTouchData: PieTouchData(
                            touchCallback: (event, response) {
                              setState(() {
                                touchedIndex =
                                    response
                                        ?.touchedSection
                                        ?.touchedSectionIndex ??
                                    -1;
                              });
                            },
                          ),
                        ),
                      ),
                      Text(
                        '${total.round()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.mutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: legend),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Events list ──────────────────────────────────────────────────────────────

class _EventsList extends StatelessWidget {
  final List<_EventItem> events;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;

  const _EventsList({
    required this.events,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'События',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                'из телеметрии',
                style: TextStyle(color: mutedColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Нет событий за период.\nДанные появятся когда устройство пришлёт телеметрию.',
                style: TextStyle(color: mutedColor, fontSize: 13),
              ),
            )
          else
            ...events.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: e.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(e.icon, color: e.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: textColor,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.subtitle,
                            style: TextStyle(color: mutedColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      e.time,
                      style: TextStyle(color: mutedColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Hero summary card ─────────────────────────────────────────────────────────

class _HeroSummaryCard extends StatelessWidget {
  final double totalKwh;
  final double avgSavings;
  final String period;

  const _HeroSummaryCard({
    required this.totalKwh,
    required this.avgSavings,
    required this.period,
  });

  String get _periodLabel {
    switch (period) {
      case 'week':
        return 'НЕДЕЛИ';
      case 'month':
        return 'МЕСЯЦА';
      default:
        return 'СЕГОДНЯ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSavings = avgSavings > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        gradient: kSunriseGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: kA2.withValues(alpha: 0.45),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ПОТРЕБЛЕНИЕ $_periodLabel',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A0F00).withValues(alpha: 0.65),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${totalKwh.toStringAsFixed(1)} kWh',
                  style: GoogleFonts.manrope(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A0F00),
                    height: 1.0,
                    letterSpacing: -1.5,
                  ),
                ),
                if (hasSavings) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.eco_rounded,
                        size: 14,
                        color: Color(0xFF1A0F00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '−${avgSavings.toStringAsFixed(0)}% к прошлому периоду',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A0F00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Text('⚡', style: TextStyle(fontSize: 40)),
        ],
      ),
    );
  }
}

// ── AI hint card ──────────────────────────────────────────────────────────────

class _AiHintCard extends StatefulWidget {
  final double savings;
  final bool isDark;
  final Color cardColor;
  final Color textColor;

  const _AiHintCard({
    required this.savings,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
  });

  @override
  State<_AiHintCard> createState() => _AiHintCardState();
}

class _AiHintCardState extends State<_AiHintCard> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kA2.withValues(alpha: widget.isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kA2.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: kSunriseGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SUNMIND ПОДСКАЗКА',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A0F00),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _dismissed = true),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: kA2.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Вы экономите ${widget.savings.toStringAsFixed(0)}% энергии! '
            'Попробуйте расписание освещения для спальни — это позволит '
            'снизить потребление ещё на 10–15%.',
            style: TextStyle(
              fontSize: 13,
              color: widget.textColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error box ────────────────────────────────────────────────────────────────

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Color cardColor;
  final Color textColor;

  const _ErrorBox({
    required this.message,
    required this.onRetry,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor, fontSize: 13),
          ),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
