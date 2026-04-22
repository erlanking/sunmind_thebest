import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanDeviceScreen extends StatefulWidget {
  const ScanDeviceScreen({super.key});

  @override
  State<ScanDeviceScreen> createState() => _ScanDeviceScreenState();
}

class _ScanDeviceScreenState extends State<ScanDeviceScreen> {
  final MobileScannerController _controller = MobileScannerController();
  String? error;
  bool scanning = true;

  String? _parseCode(String code) {
    if (!code.startsWith('SUNMIND:')) return null;
    final parts = code.split(':');
    if (parts.length != 2) return null;
    final id = parts[1].trim();
    return id.isEmpty ? null : id;
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!scanning || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;
    final parsed = _parseCode(code);
    if (parsed == null) {
      setState(() {
        error = 'Неверный формат QR';
      });
      return;
    }

    setState(() {
      scanning = false;
      error = null;
    });

    final result = await context.push('/create-zone', extra: parsed);
    if (!mounted) return;
    if (result != null) {
      context.pop(result);
      return;
    }
    setState(() => scanning = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D0F14) : const Color(0xFFF6F7FB);
    final card = isDark ? const Color(0xFF171A1F) : Colors.white;
    final text = isDark ? Colors.white : const Color(0xFF161A22);
    final muted = isDark ? const Color(0xFF858A95) : const Color(0xFF6D7481);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('Добавить устройство')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frameSize = constraints.maxWidth > 420
                ? 280.0
                : constraints.maxWidth * 0.68;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.18 : 0.08,
                          ),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Сканируйте QR-код устройства',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: text,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Наведите камеру на наклейку устройства. После сканирования мы сразу перейдём к созданию зоны.',
                          style: TextStyle(color: muted, height: 1.45),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            width: frameSize,
                            height: frameSize,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: const Color(0xFFF6C343),
                                width: 1.4,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(
                                    0xFFF6C343,
                                  ).withValues(alpha: 0.14),
                                  const Color(
                                    0xFFF6C343,
                                  ).withValues(alpha: 0.04),
                                ],
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  MobileScanner(
                                    controller: _controller,
                                    fit: BoxFit.cover,
                                    onDetect: _onDetect,
                                  ),
                                  IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 12,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.58,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: const Text(
                                          'SUNMIND:SMP-0001',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF4F6FA),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            error ??
                                'Поддерживаются только QR-коды формата SunMind.',
                            style: TextStyle(
                              color: error == null ? muted : Colors.redAccent,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
