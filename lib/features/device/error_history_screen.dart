import 'package:flutter/material.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';

class ErrorHistoryScreen extends StatefulWidget {
  final String deviceId;
  final String? deviceName;

  const ErrorHistoryScreen({
    super.key,
    required this.deviceId,
    this.deviceName,
  });

  @override
  State<ErrorHistoryScreen> createState() => _ErrorHistoryScreenState();
}

class _ErrorHistoryScreenState extends State<ErrorHistoryScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _errors = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final errors = await _api.getDeviceErrors(widget.deviceId);
      if (mounted) setState(() => _errors = errors);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(int errorId) async {
    try {
      await _api.resolveDeviceError(widget.deviceId, errorId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
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
          'История ошибок',
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
          : _errors.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 56,
                    color: const Color(0xFF30D158).withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ошибок нет за последние 7 дней',
                    style: TextStyle(color: mutedColor, fontSize: 15),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _errors.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final e = _errors[index];
                  final code = e['errorCode']?.toString() ?? '—';
                  final description = e['description']?.toString() ?? '—';
                  final status = e['status']?.toString() ?? 'active';
                  final panelStatus = e['panelStatus']?.toString() ?? 'OK';
                  final createdAt = e['createdAt']?.toString() ?? '';
                  final isActive = status == 'active';
                  final id = e['id'] is num ? (e['id'] as num).toInt() : 0;

                  final Color codeColor;
                  switch (panelStatus) {
                    case 'ERROR':
                      codeColor = const Color(0xFFFF3B30);
                      break;
                    case 'WARNING':
                      codeColor = const Color(0xFFFFCC00);
                      break;
                    default:
                      codeColor = const Color(0xFF30D158);
                  }

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                            ? codeColor.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: codeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                code,
                                style: TextStyle(
                                  color: codeColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.orange.withValues(alpha: 0.15)
                                    : Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isActive ? 'Активна' : 'Решена',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.orange
                                      : const Color(0xFF30D158),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDate(createdAt),
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                          ),
                        ),
                        if (isActive && id > 0) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF30D158),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () => _resolve(id),
                              child: const Text(
                                'Отметить как решённую',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}.${dt.month} $hh:$mm';
    } catch (_) {
      return iso;
    }
  }
}
