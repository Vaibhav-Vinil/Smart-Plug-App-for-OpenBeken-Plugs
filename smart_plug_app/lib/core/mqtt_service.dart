import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'config.dart';

class MqttService {
  MqttServerClient? _client;
  Function(Map<String, dynamic>)? onTelemetryReceived;

  Future<bool> connect({
    required String host,
    required String username,
    required String password,
  }) async {
    _client = MqttServerClient(host, SecretConfig.mqttClientId);
    _client!.port = SecretConfig.mqttBrokerPort;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.onSubscribed = _onSubscribed;
    
    try {
      await _client!.connect(username, password);
    } catch (e) {
      debugPrint('MQTT Exception: $e');
      _client!.disconnect();
      return false;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      _client!.subscribe(SecretConfig.mqttSubscribeTopic, MqttQos.atMostOnce);
      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
        try {
          final data = json.decode(pt);
          if (onTelemetryReceived != null) {
            onTelemetryReceived!(data);
          }
        } catch (e) {
          debugPrint('MQTT Payload Parsing Error: $e');
        }
      });
      return true;
    }
    return false;
  }

  void _onConnected() {
    debugPrint('MQTT Connected');
  }

  void _onDisconnected() {
    debugPrint('MQTT Disconnected');
  }

  void _onSubscribed(String topic) {
    debugPrint('MQTT Subscribed to $topic');
  }

  void publishCommand(String command) {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(command);
      _client!.publishMessage(SecretConfig.mqttPublishTopic, MqttQos.exactlyOnce, builder.payload!);
    }
  }

  void turnOff() {
    publishCommand('off');
  }

  void disconnect() {
    _client?.disconnect();
  }
}
