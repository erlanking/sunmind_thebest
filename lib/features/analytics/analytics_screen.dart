import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/models/analytics_summary.dart';
import 'package:sunmind_thebest/models/telemetry_point.dart';

const _accent = Color(0xFFFFD54F);
const _card = Color(0xFF1A1A1A);
const _bg = Color(0xFF0D0D0D);
const _muted = Color(0xFF6E6E73);
const _border = Color(0xFF2C2C2E);

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
  const _ZoneShare({required this.name, required this.color, required this.percent});
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

  String period = 'day';
  bool loading = true;
  String? error;

  double totalKwh = 0;
  double avgSavings = 0;
  int activePanels = 0;
  double lightOnHours = 0;

  List<double> consumptionByBucket = [];
  List<String> bucketLabels = [];

  List<_ZoneShare> zoneShares = [];
  List<_EventItem> events = [];

  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
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
        ids.map((id) => _api
            .getAnalyticsSummary(id, period: period)
            .then(AnalyticsSummary.fromJson)
            .catchError((_) => AnalyticsSummary.fromJson({}))),
      );

      final telemetryList = await Future.wait(
        ids.map((id) => _api
            .getTelemetry(id, period: period)
            .then((rows) => rows.map(TelemetryPoint.fromJson).toList())
            .catchError((_) => <TelemetryPoint>[])),
      );

      double kwh = 0;
      double savingsSum = 0;
      int savingsCount = 0;
      int active = 0;
      double hoursOn = 0;
      final now = DateTime.now();

      for (int i = 0; i < _devices.length; i++) {
        final s = analyticsList[i];
        kwh += s.energyKwh;
        if (s.estimatedSavingsPercent > 0) {
          savingsSum += s.estimatedSavingsPercent;
          savingsCount++;
        }
        hoursOn += s.lightOnMinutes / 60.0;

        final lastSeenRaw = _devices[i]['lastSeen'];
        if (lastSeenRaw != null) {
          final lastSeen = DateTime.tryParse(lastSeenRaw.toString());
          if (lastSeen != null && now.difference(lastSeen).inMinutes < 5) {
            active++;
          }
        }
      }

      totalKwh = kwh;
      avgSavings = savingsCount > 0 ? savingsSum / savingsCount : 0;
      activePanels = active;
      lightOnHours = hoursOn;

      final combined = telemetryList.expand((t) => t).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      _buildChart(combined);
      _buildZones(analyticsList);
      _buildEvents(combined);

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  void _buildChart(List<TelemetryPoint> points) {
    late List<String> labels;
    if (period == 'day') {
      labels = List.generate(24, (h) => h.toString().padLeft(2, '0'));
    } else if (period == 'week') {
      labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    } else {
      labels = ['Нед 1', 'Нед 2', 'Нед 3', 'Нед 4'];
    }

    final Map<String, double> buckets = {for (final l in labels) l: 0.0};

    for (int i = 0; i + 1 < points.length; i++) {
      final curr = points[i];
      final next = points[i + 1];
      final deltaMs = next.createdAt.difference(curr.createdAt).inMilliseconds;
      if (deltaMs <= 0 || deltaMs > 3600000) continue;
      const powerW = 5.0;
      final energyKwh = powerW * (curr.brightness / 255.0) * (deltaMs / 3600000) / 1000;
      String key;
      if (period == 'day') {
        key = curr.createdAt.toLocal().hour.toString().padLeft(2, '0');
      } else if (period == 'week') {
        key = labels[(curr.createdAt.toLocal().weekday - 1) % 7];
      } else {
        final weekNum = ((curr.createdAt.toLocal().day - 1) ~/ 7).clamp(0, 3);
        key = 'Нед ${weekNum + 1}';
      }
      if (buckets.containsKey(key)) buckets[key] = buckets[key]! + energyKwh;
    }

    consumptionByBucket = labels.map((l) => buckets[l]!).toList();
    bucketLabels = labels;
  }

  void _buildZones(List<AnalyticsSummary> analyticsList) {
    final Map<String, double> zoneMap = {};
    for (int i = 0; i < _devices.length; i++) {
      final zoneName = (_devices[i]['zoneName'] as String?)?.trim();
      final name = (zoneName != null && zoneName.isNotEmpty) ? zoneName : 'Прочие';
      zoneMap[name] = (zoneMap[name] ?? 0) + analyticsList[i].energyKwh;
    }
    final totalZ = zoneMap.values.fold(0.0, (a, b) => a + b);
    final sorted = zoneMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
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

      final deviceEntry = _devices.where((d) => d['deviceId'] == p.deviceId).firstOrNull;
      final zoneName = (deviceEntry?['zoneName'] as String?)?.trim();
      final label = (zoneName != null && zoneName.isNotEmpty) ? zoneName : p.deviceId;

      if (!prevMotion && p.motion) {
        evts.add(_EventItem(
          icon: Icons.visibility_rounded,
          color: Colors.orange,
          title: 'Датчик движения',
          subtitle: '$label — авто-включение',
          time: _timeStr(p.createdAt),
        ));
      }
      if (p.manualMode != prevManual) {
        evts.add(_EventItem(
          icon: p.manualMode ? Icons.pan_tool_rounded : Icons.smart_toy_rounded,
          color: p.manualMode ? Colors.purpleAccent : const Color(0xFF26C6DA),
          title: p.manualMode ? 'Ручное изменение' : 'Авто-режим',
          subtitle: p.manualMode
              ? '$label — ${(p.brightness / 255 * 100).round()}%'
              : '$label — авто',
          time: _timeStr(p.createdAt),
        ));
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _PeriodTabs(
                period: period,
                cardColor: cardColor,
                textColor: textColor,
                onChanged: (p) {
                  setState(() => period = p);
                  _load();
                },
              ),
              const SizedBox(height: 20),
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
                  activePanels: activePanels,
                  lightOnHours: lightOnHours,
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

// ── Stats 2x2 grid ───────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final double totalKwh;
  final double avgSavings;
  final int activePanels;
  final double lightOnHours;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;

  const _StatsGrid({
    required this.totalKwh,
    required this.avgSavings,
    required this.activePanels,
    required this.lightOnHours,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
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
          label: 'АКТИВНЫХ',
          value: '$activePanels',
          badge: 'сейчас',
          badgeColor: const Color(0xFF003838),
          cardColor: cardColor,
          textColor: textColor,
          mutedColor: mutedColor,
        ),
        _StatCard(
          label: 'РАБОТА',
          value: '${lightOnHours.toStringAsFixed(1)}h',
          badge: 'сегодня',
          badgeColor: const Color(0xFF003838),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.0,
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
                        .map((s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(4)} кВт',
                              TextStyle(
                                color: _accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ))
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
                                  response?.touchedSection?.touchedSectionIndex ?? -1;
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
              Expanded(
                child: Column(
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
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
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
                ),
              ),
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
            ...events.map((e) => Padding(
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
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 12,
                              ),
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
                )),
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
