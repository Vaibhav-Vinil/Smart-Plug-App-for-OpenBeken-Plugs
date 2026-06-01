import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'device_defaults.dart';

class MqttService {
  MqttServerClient? _client;
  Function(String topic, String payload)? onTelemetryReceived;

  String? _defaultPublishTopic;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<bool> connect({
    required String host,
    required String username,
    required String password,
    bool useWebSocket = false,
    int port = DeviceDefaults.mqttTcpPort,
    bool secure = false,
    required String subscribeTopic,
    String? defaultPublishTopic,
  }) async {
    if (subscribeTopic.isEmpty) {
      debugPrint('MQTT connect aborted: subscribe topic is empty');
      return false;
    }

    if (_client?.connectionStatus?.state == MqttConnectionState.connected &&
        _client?.server == host) {
      _defaultPublishTopic = defaultPublishTopic;
      return true;
    }

    _defaultPublishTopic = defaultPublishTopic;
    final uniqueClientId =
        '${DeviceDefaults.mqttClientIdPrefix}_${DateTime.now().millisecondsSinceEpoch}';
    _client = MqttServerClient.withPort(host, uniqueClientId, port);
    _client!.useWebSocket = useWebSocket;
    if (!useWebSocket) {
      _client!.secure = secure;
    }
    _client!.logging(on: useWebSocket);
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;

    _client!.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(uniqueClientId)
        .startClean();

    try {
      await _client!.connect(username, password);
    } catch (e) {
      debugPrint('MQTT Exception: $e');
      _client!.disconnect();
      return false;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      _client!.subscribe(subscribeTopic, MqttQos.atMostOnce);
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );
        final topic = c[0].topic;
        onTelemetryReceived?.call(topic, pt);
      });
      return true;
    }
    return false;
  }

  void _onConnected() => debugPrint('MQTT Connected');
  void _onDisconnected() => debugPrint('MQTT Disconnected');
  void _onSubscribed(String topic) => debugPrint('MQTT Subscribed to $topic');

  void publishCommand(String command, {String? topic}) {
    final target = topic ?? _defaultPublishTopic;
    if (target == null || target.isEmpty) {
      debugPrint('MQTT publish skipped: no topic configured');
      return;
    }
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(command);
      _client!.publishMessage(
        target,
        MqttQos.atLeastOnce,
        builder.payload!,
      );
    }
  }

  void turnOff({String? topic}) => publishCommand('off', topic: topic);

  void disconnect() {
    _client?.disconnect();
  }
}
