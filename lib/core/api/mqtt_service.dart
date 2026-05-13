import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  late final MqttServerClient _client = _createClient();

  bool _connected = false;
  bool _intentionalDisconnect = false;
  final Set<String> _subscriptions = <String>{};

  /// Вызывается при неожиданном разрыве соединения с MQTT-брокером.
  void Function()? onDisconnectedCallback;

  /// Вызывается при успешном восстановлении соединения с MQTT-брокером.
  void Function()? onConnectedCallback;

  void _handleDisconnected() {
    _connected = false;
    if (!_intentionalDisconnect) {
      onDisconnectedCallback?.call();
    }
    _intentionalDisconnect = false;
  }

  MqttServerClient _createClient() {
    return MqttServerClient(
        'broker.hivemq.com',
        'sunmind-mobile-${DateTime.now().millisecondsSinceEpoch}',
      )
      ..port = 1883
      ..logging(on: false)
      ..keepAlivePeriod = 20
      ..onDisconnected = _handleDisconnected;
  }

  Future<void> _ensureConnected() async {
    if (_connected) return;
    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(_client.clientIdentifier)
        .startClean();
    final res = await _client.connect();
    if (res?.state == MqttConnectionState.connected) {
      _connected = true;
      onConnectedCallback?.call();
    } else {
      throw Exception('MQTT connect failed: ${res?.state}');
    }
  }

  Future<void> publish(String topic, String payload) async {
    await _ensureConnected();
    final builder = MqttClientPayloadBuilder();
    builder.addUTF8String(payload);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> subscribe(String topic, {MqttQos qos = MqttQos.atLeastOnce}) async {
    await _ensureConnected();
    _client.subscribe(topic, qos);
    _subscriptions.add(topic);
  }

  Future<void> disconnect() async {
    if (_subscriptions.isNotEmpty) {
      for (final topic in _subscriptions.toList()) {
        _client.unsubscribe(topic);
      }
      _subscriptions.clear();
    }

    if (_connected) {
      _intentionalDisconnect = true;
      _client.disconnect();
    }
    _connected = false;
  }
}
