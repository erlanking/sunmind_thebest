import 'dart:convert';

import 'package:easy_localization/easy_localization.dart' hide DateFormat;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/api/mqtt_service.dart';
import 'package:sunmind_thebest/core/widgets/battery_status_card.dart';
import 'package:sunmind_thebest/models/device_schedule.dart';
import 'package:sunmind_thebest/models/device_status.dart';

class DeviceScreen extends StatefulWidget {
  final String deviceId;
  const DeviceScreen({super.key, required this.deviceId});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final ApiService _api = ApiService();
  final MqttService _mqtt = MqttService();

  DeviceStatus? status;
  DeviceSchedule? schedule;
  bool loading = true;
  bool saving = false;
  bool sendingWifi = false;
  String? error;

  late int onHour;
  late int onMinute;
  late int offHour;
  late int offMinute;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final s = DeviceStatus.fromJson(
        await _api.getDeviceStatus(widget.deviceId),
      );
      final sch = DeviceSchedule.fromJson(
        await _api.getDeviceSchedule(widget.deviceId),
      );
      onHour = sch.onHour;
      onMinute = sch.onMinute;
      offHour = sch.offHour;
      offMinute = sch.offMinute;
      setState(() {
        status = s;
        schedule = sch;
      });
    } catch (e) {
      setState(() {
        error = ApiService.isOfflineError(e)
            ? 'errors.no_internet_device'.tr()
            : e.toString();
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickTime(bool isOn) async {
    final initial = TimeOfDay(
      hour: isOn ? onHour : offHour,
      minute: isOn ? onMinute : offMinute,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isOn) {
        onHour = picked.hour;
        onMinute = picked.minute;
      } else {
        offHour = picked.hour;
        offMinute = picked.minute;
      }
    });
  }

  Future<void> _showWifiDialog() async {
    final ssidCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscure = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF171A1F),
          title: Text('wifi.change_action'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ssidCtrl,
                decoration: InputDecoration(labelText: 'wifi.ssid'.tr()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'auth.password'.tr(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('common.send'.tr()),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final ssid = ssidCtrl.text.trim();
    if (ssid.isEmpty) return;

    setState(() => sendingWifi = true);
    try {
      final topic = 'home/${widget.deviceId}/wifi/config';
      final payload = jsonEncode({'ssid': ssid, 'password': passCtrl.text});
      await _mqtt.publish(topic, payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('wifi.sent'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => sendingWifi = false);
    }
  }

  Future<void> _saveSchedule() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await _api.updateDeviceSchedule(
        widget.deviceId,
        onHour: onHour,
        onMinute: onMinute,
        offHour: offHour,
        offMinute: offMinute,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('schedule.schedule_saved'.tr())));
      }
      await _load();
    } catch (e) {
      setState(() {
        error = ApiService.isOfflineError(e)
            ? 'errors.internet'.tr()
            : e.toString();
      });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('device.device'.tr()),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? _ErrorBox(error: error!, onRetry: _load)
              : ListView(
                  children: [
                    _sectionTitle('common.status'.tr()),
                    _card(
                      child: Column(
                        children: [
                          _row('ID', status?.deviceId ?? ''),
                          _row('device.illuminance'.tr(), '${status?.lux ?? 0} lx'),
                          _row(
                            'device.temperature'.tr(),
                            '${(status?.temperature ?? 0).toStringAsFixed(1)} °C',
                          ),
                          _row(
                            'device.humidity'.tr(),
                            '${(status?.humidity ?? 0).toStringAsFixed(1)} %',
                          ),
                          _row(
                            'device.motion'.tr(),
                            status?.motion == true ? 'common.yes'.tr() : 'common.no'.tr(),
                          ),
                          _row('device.brightness'.tr(), '${status?.brightness ?? 0}'),
                          const SizedBox(height: 10),
                          BatteryStatusCard(
                            batteryPercent: status?.batteryPercent ?? 0,
                            batteryVoltage: status?.batteryVoltage ?? 0,
                          ),
                          const SizedBox(height: 10),
                          _row(
                            'device.manual_mode_label'.tr(),
                            status?.manualMode == true ? 'common.on'.tr() : 'common.off'.tr(),
                          ),
                          _row(
                            'device.last_online'.tr(),
                            status?.lastSeen != null
                                ? DateFormat(
                                    'dd.MM.yyyy HH:mm',
                                  ).format(status!.lastSeen!.toLocal())
                                : '—',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('schedule.schedule'.tr()),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'schedule.turn_on_at'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          _timeButton(onHour, onMinute, () => _pickTime(true)),
                          const SizedBox(height: 16),
                          Text(
                            'schedule.turn_off_at'.tr(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          _timeButton(
                            offHour,
                            offMinute,
                            () => _pickTime(false),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: saving ? null : _saveSchedule,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: saving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'common.save'.tr(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('wifi.setup'.tr()),
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'wifi.mqtt_hint'.tr(),
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: sendingWifi ? null : _showWifiDialog,
                              icon: sendingWifi
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.wifi),
                              label: Text('wifi.change_action'.tr()),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171A1F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF262A32)),
      ),
      child: child,
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _timeButton(int h, int m, VoidCallback onTap) {
    final text =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF2D313A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Icon(Icons.schedule),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        t,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: Text('common.retry'.tr())),
        ],
      ),
    );
  }
}
