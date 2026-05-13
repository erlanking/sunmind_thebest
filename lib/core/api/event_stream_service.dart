import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class RealtimeEvent {
  final String type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  RealtimeEvent({
    required this.type,
    required this.payload,
    required this.timestamp,
  });
}

/// Клиент SSE на /events/stream.
class EventStreamService {
  final _controller = StreamController<RealtimeEvent>.broadcast();
  StreamSubscription<String>? _subscription;
  http.Client? _client;

  Stream<RealtimeEvent> get stream => _controller.stream;

  Future<void> connect() async {
    if (_subscription != null) return;

    _client = http.Client();
    final request = http.Request(
      'GET',
      Uri.parse('${ApiService.baseUrl}/api/motion/stream'),
    );
    request.headers['Accept'] = 'text/event-stream';

    final response = await _client!.send(request);

    String? currentEvent;
    String? currentData;

    _subscription = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            if (line.startsWith('event:')) {
              currentEvent = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              currentData = line.substring(5).trim();
            } else if (line.trim().isEmpty) {
              if (currentData != null) {
                try {
                  final map = jsonDecode(currentData!) as Map<String, dynamic>;
                  final tsStr =
                      map['ts'] as String? ?? map['timestamp'] as String? ?? '';
                  final ts = tsStr.isNotEmpty
                      ? DateTime.tryParse(tsStr)
                      : DateTime.now();
                  _controller.add(
                    RealtimeEvent(
                      type:
                          currentEvent ?? (map['type'] as String? ?? 'unknown'),
                      payload: map['payload'] as Map<String, dynamic>? ?? map,
                      timestamp: ts ?? DateTime.now(),
                    ),
                  );
                } catch (_) {
                  // пропускаем неверный json
                }
              }
              currentEvent = null;
              currentData = null;
            }
          },
          onError: (_) {
            // можно добавить реконнект
          },
          onDone: () {
            _subscription = null;
          },
        );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _client?.close();
    await _controller.close();
  }
}
