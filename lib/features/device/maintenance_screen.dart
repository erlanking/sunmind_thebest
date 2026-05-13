import 'package:flutter/material.dart';
import 'package:sunmind_thebest/core/api/api_service.dart';

class MaintenanceScreen extends StatefulWidget {
  final String deviceId;
  final String? deviceName;

  const MaintenanceScreen({
    super.key,
    required this.deviceId,
    this.deviceName,
  });

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  bool _saving = false;
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
      final history = await _api.getMaintenanceHistory(widget.deviceId);
      if (mounted) setState(() => _history = history);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showRecordDialog() {
    final notesController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF17171B) : Colors.white,
        title: const Text('Зафиксировать обслуживание'),
        content: TextField(
          controller: notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Заметки (опционально)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _recordMaintenance(notes: notesController.text.trim());
            },
            child: const Text(
              'Сохранить',
              style: TextStyle(color: Color(0xFF30D158)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordMaintenance({String? notes}) async {
    setState(() => _saving = true);
    try {
      await _api.recordMaintenance(
        widget.deviceId,
        notes: notes?.isNotEmpty == true ? notes : null,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Обслуживание зафиксировано'),
            backgroundColor: Color(0xFF30D158),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
          'Техническое обслуживание',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _showRecordDialog,
        backgroundColor: const Color(0xFFFFD54F),
        foregroundColor: Colors.black,
        icon: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.build_outlined),
        label: const Text('Обслуживание выполнено'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: mutedColor)))
          : _history.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.build_circle_outlined,
                    size: 56,
                    color: mutedColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'История обслуживания пуста',
                    style: TextStyle(color: mutedColor, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Нажмите кнопку внизу чтобы зафиксировать обслуживание',
                    style: TextStyle(color: mutedColor, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _history.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final m = _history[index];
                  final id = m['id'] as int?;
                  final createdAt = m['createdAt']?.toString() ?? '';
                  final notes = m['notes']?.toString();
                  final triggerType = m['triggerType']?.toString() ?? 'manual';

                  return Dismissible(
                    key: ValueKey(id ?? index),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF17171B) : Colors.white,
                          title: const Text('Удалить запись?'),
                          content: const Text('Это действие нельзя отменить.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Удалить', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      ) ?? false;
                    },
                    onDismissed: (_) async {
                      if (id == null) return;
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _api.deleteMaintenance(widget.deviceId, id);
                        if (mounted) setState(() => _history.removeAt(index));
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Ошибка удаления: $e')),
                        );
                        if (mounted) _load();
                      }
                    },
                    child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD54F).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.build_outlined,
                            color: Color(0xFFFFD54F),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _triggerLabel(triggerType),
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
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
                              if (notes != null && notes.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  notes,
                                  style: TextStyle(
                                    color: mutedColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  );
                },
              ),
            ),
    );
  }

  String _triggerLabel(String type) {
    switch (type) {
      case 'scheduled':
        return 'Плановое обслуживание';
      case 'data_driven':
        return 'По данным устройства';
      default:
        return 'Ручное обслуживание';
    }
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
