import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';
import 'package:sunmind_thebest/core/services/haptic_service.dart';

// ── Battery tab (standalone page for bottom nav) ──────────────────────

class BatteryTabScreen extends StatefulWidget {
  const BatteryTabScreen({super.key});

  @override
  State<BatteryTabScreen> createState() => _BatteryTabScreenState();
}

class _BatteryTabScreenState extends State<BatteryTabScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final list = await _api.getDevices();
      if (mounted) setState(() => _devices = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF6D7481);

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        body: const Center(child: CircularProgressIndicator(color: _kA2)),
      );
    }

    if (_devices.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text(
            'battery.title'.tr(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.battery_unknown_rounded, size: 64, color: mutedColor),
              const SizedBox(height: 16),
              Text(
                'home.no_devices'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'device.no_devices_add'.tr(),
                style: TextStyle(color: mutedColor, fontSize: 14),
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: _loadDevices,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('common.refresh'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    // Always show the first device directly — no selection screen
    final d = _devices.first;
    final rawId = (d['deviceId'] ?? d['id'] ?? '').toString();
    final id = rawId == 'SMP-0001' ? 'SMP-0002' : rawId;
    return BatteryScreen(deviceId: id);
  }
}

const _kA1 = Color(0xFFFFD54F);
const _kA2 = Color(0xFFFF9F43);
const _kA3 = Color(0xFFFF6B35);
const _kGreen = Color(0xFF39B86D);
const _kBlue = Color(0xFF5E9EFF);
const _kRed = Color(0xFFE55454);

class BatteryScreen extends StatefulWidget {
  final String deviceId;
  final String? deviceName;

  const BatteryScreen({
    super.key,
    required this.deviceId,
    this.deviceName,
  });

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _saving = false;

  // Battery state
  int _batteryPercent = 0;
  double _batteryVoltage = 0;
  bool _isCharging = false;
  String _powerSource = 'battery'; // 'battery' | 'ac'

  // Mode: 'manual' | 'auto'
  String _chargeMode = 'manual';

  // Auto mode settings
  double _lowThreshold = 20; // switch to AC when below X%
  double _fullThreshold = 90; // stop charging when above X%
  bool _autoSolar = true; // auto-charge when solar available

  // Loading states
  bool _chargingLoading = false;
  bool _sourceLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    if (widget.deviceId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final status = await _api.getDeviceStatus(widget.deviceId);
      if (!mounted) return;
      setState(() {
        _batteryPercent =
            ((status['batteryPercent'] ?? status['battery'] ?? 0) as num)
                .toInt()
                .clamp(0, 100);
        _batteryVoltage =
            ((status['batteryVoltage'] ?? 0) as num).toDouble();
        _isCharging = status['isCharging'] == true;
        final ps = (status['powerSource'] as String?)?.toLowerCase();
        if (ps == 'ac' || ps == 'battery') _powerSource = ps!;
        final cm = (status['chargeMode'] as String?)?.toLowerCase();
        if (cm == 'auto' || cm == 'manual') _chargeMode = cm!;
        _lowThreshold =
            ((status['lowBatteryThreshold'] ?? 20) as num).toDouble();
        _fullThreshold =
            ((status['fullChargeThreshold'] ?? 90) as num).toDouble();
        _autoSolar = status['autoSolarCharge'] != false;
      });
    } catch (_) {
      // use defaults
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setCharging(bool value) async {
    if (_chargingLoading) return;
    HapticService.medium();
    final prev = _isCharging;
    setState(() {
      _chargingLoading = true;
      _isCharging = value;
    });
    try {
      await _api.setCharging(widget.deviceId, isCharging: value);
      HapticService.success();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCharging = prev);
      _showError(
        ApiService.isOfflineError(e)
            ? 'errors.internet_short'.tr()
            : 'errors.charge_mode'.tr(),
      );
    } finally {
      if (mounted) setState(() => _chargingLoading = false);
    }
  }

  Future<void> _setPowerSource(String source) async {
    if (_sourceLoading) return;
    HapticService.medium();
    final prev = _powerSource;
    setState(() {
      _sourceLoading = true;
      _powerSource = source;
    });
    try {
      await _api.setPowerSource(widget.deviceId, powerSource: source);
      HapticService.success();
    } catch (e) {
      if (!mounted) return;
      setState(() => _powerSource = prev);
      _showError(
        ApiService.isOfflineError(e)
            ? 'errors.internet_short'.tr()
            : 'errors.power_source'.tr(),
      );
    } finally {
      if (mounted) setState(() => _sourceLoading = false);
    }
  }

  Future<void> _saveAutoSettings() async {
    if (_saving) return;
    HapticService.medium();
    setState(() => _saving = true);
    try {
      await _api.setBatteryChargeMode(
        widget.deviceId,
        mode: _chargeMode,
        lowThreshold: _lowThreshold.round(),
        fullThreshold: _fullThreshold.round(),
        autoSolar: _autoSolar,
      );
      HapticService.success();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('battery.settings_saved'.tr())),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError(
        ApiService.isOfflineError(e)
            ? 'errors.internet_short'.tr()
            : 'errors.save_settings'.tr(),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color get _batteryColor {
    if (_batteryPercent <= 20) return _kRed;
    if (_batteryPercent <= 50) return _kA2;
    return _kGreen;
  }

  IconData get _batteryIcon {
    if (_batteryPercent <= 20) return Icons.battery_alert_rounded;
    if (_batteryPercent <= 50) return Icons.battery_3_bar_rounded;
    if (_isCharging) return Icons.battery_charging_full_rounded;
    return Icons.battery_full_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final panelColor = isDark ? const Color(0xFF171A1F) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF161A22);
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF6D7481);

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
          'battery.title'.tr(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: mutedColor),
            onPressed: _loading ? null : _loadStatus,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kA2))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      children: [
                        _HeroBatteryCard(
                          percent: _batteryPercent,
                          voltage: _batteryVoltage,
                          isCharging: _isCharging,
                          powerSource: _powerSource,
                          batteryColor: _batteryColor,
                          batteryIcon: _batteryIcon,
                          panelColor: panelColor,
                          textColor: textColor,
                          mutedColor: mutedColor,
                        ),
                        const SizedBox(height: 16),
                        _ModeSelector(
                          mode: _chargeMode,
                          panelColor: panelColor,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          onChanged: (m) => setState(() => _chargeMode = m),
                        ),
                        const SizedBox(height: 16),
                        if (_chargeMode == 'manual') ...[
                          _PowerSourceCard(
                            powerSource: _powerSource,
                            loading: _sourceLoading,
                            batteryPercent: _batteryPercent,
                            panelColor: panelColor,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            onChanged: _setPowerSource,
                          ),
                          const SizedBox(height: 16),
                          _ChargingToggleCard(
                            isCharging: _isCharging,
                            loading: _chargingLoading,
                            batteryPercent: _batteryPercent,
                            panelColor: panelColor,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            onChanged: _setCharging,
                          ),
                        ],
                        if (_chargeMode == 'auto')
                          _AutoModeCard(
                            lowThreshold: _lowThreshold,
                            fullThreshold: _fullThreshold,
                            autoSolar: _autoSolar,
                            panelColor: panelColor,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            onLowChanged: (v) => setState(() => _lowThreshold = v),
                            onFullChanged: (v) => setState(() => _fullThreshold = v),
                            onSolarChanged: (v) => setState(() => _autoSolar = v),
                          ),
                      ],
                    ),
                  ),
                ),
                // ── Фиксированная кнопка «Сохранить» для авто-режима ──
                if (_chargeMode == 'auto')
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveAutoSettings,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kA2,
                            foregroundColor: const Color(0xFF1A0F00),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF1A0F00),
                                  ),
                                )
                              : Text(
                                  'battery.save_mode'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
              ],
            ),
    );
  }
}

// ── Hero battery card ──────────────────────────────────────────────────

class _HeroBatteryCard extends StatelessWidget {
  final int percent;
  final double voltage;
  final bool isCharging;
  final String powerSource;
  final Color batteryColor;
  final IconData batteryIcon;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;

  const _HeroBatteryCard({
    required this.percent,
    required this.voltage,
    required this.isCharging,
    required this.powerSource,
    required this.batteryColor,
    required this.batteryIcon,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: batteryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Icon + percent row
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: batteryColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Icon(batteryIcon, color: batteryColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$percent%',
                          style: TextStyle(
                            color: batteryColor,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (voltage > 0) ...[
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${voltage.toStringAsFixed(1)} V',
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _StatusChip(
                          label: isCharging ? 'battery.charging'.tr() : 'battery.discharging'.tr(),
                          color: isCharging ? _kGreen : mutedColor,
                          icon: isCharging
                              ? Icons.bolt_rounded
                              : Icons.battery_std_rounded,
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(
                          label: powerSource == 'ac' ? 'battery.socket'.tr() : 'battery.akb'.tr(),
                          color: powerSource == 'ac' ? _kBlue : batteryColor,
                          icon: powerSource == 'ac'
                              ? Icons.power_rounded
                              : Icons.battery_full_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 12,
              backgroundColor: batteryColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
            ),
          ),

          const SizedBox(height: 12),

          // Threshold labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%',
                  style: TextStyle(fontSize: 11, color: mutedColor)),
              Text(
                _batteryLabel(percent),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: batteryColor,
                ),
              ),
              Text('100%',
                  style: TextStyle(fontSize: 11, color: mutedColor)),
            ],
          ),
        ],
      ),
    );
  }

  String _batteryLabel(int p) {
    if (p <= 20) return 'battery.low_charge'.tr();
    if (p <= 50) return 'battery.medium_charge'.tr();
    if (p >= 90) return 'battery.full_charge'.tr();
    return 'battery.normal_charge'.tr();
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
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
    );
  }
}

// ── Mode selector ──────────────────────────────────────────────────────

class _ModeSelector extends StatelessWidget {
  final String mode;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<String> onChanged;

  const _ModeSelector({
    required this.mode,
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
            'battery.mode_section'.tr(),
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
                child: _ModeBtn(
                  icon: Icons.tune_rounded,
                  label: 'battery.mode_manual'.tr(),
                  hint: 'battery.mode_manual_hint'.tr(),
                  selected: mode == 'manual',
                  onTap: () => onChanged('manual'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModeBtn(
                  icon: Icons.autorenew_rounded,
                  label: 'battery.mode_auto'.tr(),
                  hint: 'battery.mode_auto_hint'.tr(),
                  selected: mode == 'auto',
                  onTap: () => onChanged('auto'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleTextColor = isDark ? Colors.white70 : const Color(0xFF6D7481);
    final idleBorder = isDark ? Colors.white24 : const Color(0xFFD0D5E0);
    final idleBg = isDark ? Colors.transparent : const Color(0xFFF2F4F8);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [_kA1, _kA2, _kA3],
                  stops: [0.0, 0.55, 1.0],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : idleBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? Colors.transparent : idleBorder,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
              color: selected ? const Color(0xFF1A0F00) : idleTextColor,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: selected ? const Color(0xFF1A0F00) : idleTextColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? const Color(0xFF1A0F00).withValues(alpha: 0.6)
                    : idleTextColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Power source card ──────────────────────────────────────────────────

class _PowerSourceCard extends StatelessWidget {
  final String powerSource;
  final bool loading;
  final int batteryPercent;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<String> onChanged;

  const _PowerSourceCard({
    required this.powerSource,
    required this.loading,
    required this.batteryPercent,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isBattery = powerSource == 'battery';
    final batteryLow = batteryPercent > 0 && batteryPercent <= 20;

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
            'battery.source_section'.tr(),
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
                child: GestureDetector(
                  onTap: loading ? null : () => onChanged('battery'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: isBattery
                          ? LinearGradient(
                              colors: [
                                _kGreen.withValues(alpha: 0.85),
                                _kGreen,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isBattery ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isBattery ? Colors.transparent : Colors.white24,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: loading && isBattery
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Column(
                            children: [
                              Icon(
                                batteryLow && isBattery
                                    ? Icons.battery_alert_rounded
                                    : Icons.battery_full_rounded,
                                color: isBattery ? Colors.white : _kGreen,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'battery.akb'.tr(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isBattery
                                      ? Colors.white
                                      : Colors.white60,
                                ),
                              ),
                              if (batteryPercent > 0) ...[
                                const SizedBox(height: 3),
                                Text(
                                  '$batteryPercent%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isBattery
                                        ? Colors.white70
                                        : (batteryLow
                                            ? _kRed
                                            : Colors.white38),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: loading ? null : () => onChanged('ac'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: !isBattery
                          ? LinearGradient(
                              colors: [
                                _kBlue.withValues(alpha: 0.85),
                                _kBlue,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: !isBattery ? null : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: !isBattery
                            ? Colors.transparent
                            : Colors.white24,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: loading && !isBattery
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Column(
                            children: [
                              Icon(
                                Icons.power_rounded,
                                color:
                                    !isBattery ? Colors.white : _kBlue,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'battery.socket'.tr(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: !isBattery
                                      ? Colors.white
                                      : Colors.white60,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'battery.socket_220v'.tr(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: !isBattery
                                      ? Colors.white70
                                      : Colors.white38,
                                ),
                              ),
                            ],
                          ),
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

// ── Charging toggle card ───────────────────────────────────────────────

class _ChargingToggleCard extends StatelessWidget {
  final bool isCharging;
  final bool loading;
  final int batteryPercent;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<bool> onChanged;

  const _ChargingToggleCard({
    required this.isCharging,
    required this.loading,
    required this.batteryPercent,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isFull = batteryPercent >= 90;
    final chargeColor = _kGreen;
    final offColor = _kRed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: (isCharging ? chargeColor : offColor)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Icon(
              isCharging
                  ? Icons.battery_charging_full_rounded
                  : Icons.battery_std_rounded,
              color: isCharging ? chargeColor : offColor,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'battery.charging_section'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: mutedColor,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isCharging
                      ? 'battery.charging_active'.tr()
                      : isFull
                          ? 'battery.battery_full'.tr()
                          : 'battery.charging_off'.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: isCharging,
                  onChanged: isFull ? null : onChanged,
                  activeThumbColor: chargeColor,
                  activeTrackColor: chargeColor.withValues(alpha: 0.3),
                ),
        ],
      ),
    );
  }
}

// ── Auto mode card ─────────────────────────────────────────────────────

class _AutoModeCard extends StatelessWidget {
  final double lowThreshold;
  final double fullThreshold;
  final bool autoSolar;
  final Color panelColor;
  final Color textColor;
  final Color mutedColor;
  final ValueChanged<double> onLowChanged;
  final ValueChanged<double> onFullChanged;
  final ValueChanged<bool> onSolarChanged;

  const _AutoModeCard({
    required this.lowThreshold,
    required this.fullThreshold,
    required this.autoSolar,
    required this.panelColor,
    required this.textColor,
    required this.mutedColor,
    required this.onLowChanged,
    required this.onFullChanged,
    required this.onSolarChanged,
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
            'battery.auto_mode_settings'.tr(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: mutedColor,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 20),

          // Auto solar toggle
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _kA2.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.wb_sunny_rounded,
                    color: _kA2, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'battery.auto_solar'.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'battery.auto_solar_hint'.tr(),
                      style: TextStyle(fontSize: 11, color: mutedColor),
                    ),
                  ],
                ),
              ),
              Switch(
                value: autoSolar,
                onChanged: onSolarChanged,
                activeThumbColor: _kA2,
                activeTrackColor: _kA2.withValues(alpha: 0.3),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: mutedColor.withValues(alpha: 0.15)),
          const SizedBox(height: 20),

          // Low threshold slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.battery_alert_rounded,
                      color: _kRed, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'battery.low_threshold'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${lowThreshold.round()}%',
                  style: const TextStyle(
                    color: _kRed,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'battery.low_threshold_hint'.tr(),
            style: TextStyle(fontSize: 11, color: mutedColor),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _kRed,
              inactiveTrackColor: _kRed.withValues(alpha: 0.2),
              thumbColor: _kRed,
              overlayColor: _kRed.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: lowThreshold,
              min: 5,
              max: 50,
              divisions: 9,
              onChanged: onLowChanged,
            ),
          ),

          const SizedBox(height: 12),
          Divider(color: mutedColor.withValues(alpha: 0.15)),
          const SizedBox(height: 12),

          // Full threshold slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.battery_full_rounded,
                      color: _kGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'battery.full_threshold'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${fullThreshold.round()}%',
                  style: const TextStyle(
                    color: _kGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'battery.full_threshold_hint'.tr(),
            style: TextStyle(fontSize: 11, color: mutedColor),
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _kGreen,
              inactiveTrackColor: _kGreen.withValues(alpha: 0.2),
              thumbColor: _kGreen,
              overlayColor: _kGreen.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: fullThreshold,
              min: 60,
              max: 100,
              divisions: 8,
              onChanged: onFullChanged,
            ),
          ),

          const SizedBox(height: 12),

          // Info hint
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kA2.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: _kA2.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: _kA2, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'battery.auto_mode_info'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: mutedColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
