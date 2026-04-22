import 'package:mqtt_client/mqtt_server_client.dart';
void main() {
  final client = MqttServerClient('test', 'id');
  print('Use WebSocket: ${client.useWebSocket}');
  // Try to see if there is any web socket path property
}
