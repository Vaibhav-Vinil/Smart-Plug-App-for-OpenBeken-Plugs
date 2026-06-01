import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

void main() async {
  // Test if MqttServerClient correctly uses the path /mqtt
  final client = MqttServerClient.withPort('ws://localhost:8081/mqtt', 'test_client_dart', 8081);
  client.useWebSocket = true;
  client.logging(on: true);
  
  final connMess = MqttConnectMessage()
      .withClientIdentifier('test_client_dart')
      .startClean();
  client.connectionMessage = connMess;

  try {
    print('Connecting...');
    await client.connect();
    print('Connected: ${client.connectionStatus?.state}');
    client.disconnect();
  } catch (e) {
    print('Exception: $e');
  }
}
