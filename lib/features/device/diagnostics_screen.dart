import 'package:flutter/material.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  final String deviceId;
  final Map<String, dynamic>? initialData;

  const DiagnosticsScreen({
    super.key,
    required this.deviceId,
    this.initialData,
  });

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _status = widget.initialData;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _api.getDevices();
      final found = devices.firstWhere(
        (d) => d['deviceId'] == widget.deviceId,
        orElse: () => <String, dynamic>{},
      );
      if (mounted) setState(() => _status = found.isNotEmpty ? found : _status);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0D) : const Color(0xFFF2F2F7);
    final cardBg = isDark ? const Color(0xFF17171B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final mutedColor = isDark ? const Color(0xFF6E6E75) : const Color(0xFF8E8E93);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(
          'Диагностика',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _load,
          ),
        ],
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: mutedColor)))
          : _status == null || _status!.isEmpty
          ? Center(
              child: Text(
                'Нет данных',
                style: TextStyle(color: mutedColor),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _statusHeader(cardBg, textColor, mutedColor),
                  const SizedBox(height: 16),
                  _infoCard(
                    'Электрика',
                    Icons.bolt_outlined,
                    cardBg, textColor, mutedColor,
                    [
                      _row('Яркость', '${_status!['brightness'] ?? 0}'),
                      _row('Освещённость', '${_status!['lux'] ?? 0} lx'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoCard(
                    'Батарея',
                    Icons.battery_full,
                    cardBg, textColor, mutedColor,
                    [
                      _row('Заряд', '${_status!['batteryPercent'] ?? '—'}%'),
                      _row(
                        'Напряжение',
                        _status!['batteryVoltage'] != null
                            ? '${_status!['batteryVoltage']} В'
                            : '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoCard(
                    'Окружающая среда',
                    Icons.thermostat_outlined,
                    cardBg, textColor, mutedColor,
                    [
                      _row(
                        'Температура',
                        _status!['temperature'] != null
                            ? '${_status!['temperature']}°C'
                            : '—',
                      ),
                      _row(
                        'Влажность',
                        _status!['humidity'] != null
                            ? '${_status!['humidity']}%'
                            : '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoCard(
                    'Режим и связь',
                    Icons.settings_remote_outlined,
                    cardBg, textColor, mutedColor,
                    [
                      _row('Режим', _status!['mode'] ?? 'auto'),
                      _row(
                        'Движение',
                        (_status!['motion'] == true || _status!['motion_active'] == true)
                            ? 'Обнаружено'
                            : 'Нет',
                      ),
                      _row(
                        'Подключение',
                        _status!['connected'] != false ? 'Online' : 'Offline',
                      ),
                      if (_status!['firmwareVersion'] != null)
                        _row('Прошивка', _status!['firmwareVersion'].toString()),
                      if (_status!['lastSeen'] != null)
                        _row(
                          'Последний сигнал',
                          _formatDate(_status!['lastSeen'].toString()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _infoCard(
                    'Ночной охранный режим',
                    Icons.shield_moon_outlined,
                    cardBg, textColor, mutedColor,
                    [
                      _row(
                        'Статус',
                        _status!['nightGuardEnabled'] == true
                            ? 'Включён'
                            : 'Выключен',
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statusHeader(Color cardBg, Color textColor, Color mutedColor) {
    final s = (_status!['deviceStatus'] ?? 'OK').toString();
    final Color sColor;
    final String sLabel;
    switch (s) {
      case 'ERROR':
        sColor = const Color(0xFFFF3B30);
        sLabel = 'ERROR — требуется вмешательство';
        break;
      case 'WARNING':
        sColor = const Color(0xFFFFCC00);
        sLabel = 'WARNING — обратите внимание';
        break;
      default:
        sColor = const Color(0xFF30D158);
        sLabel = 'OK — всё в порядке';
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: sColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            s == 'ERROR'
                ? Icons.error_outline
                : s == 'WARNING'
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: sColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Статус панели',
                  style: TextStyle(color: mutedColor, fontSize: 12),
                ),
                Text(
                  sLabel,
                  style: TextStyle(
                    color: sColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
    String title,
    IconData icon,
    Color cardBg,
    Color textColor,
    Color mutedColor,
    List<Widget> rows,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: mutedColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}.${dt.month}.${dt.year} $hh:$mm';
    } catch (_) {
      return iso;
    }
  }
}
