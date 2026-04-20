class SecretConfig {
  // Constants
  static const String localHttpPort = '80';
  static const int mqttBrokerPort = 1883;
  static const String mqttClientId = 'flutter_client_001';

  // MQTT Topics (These could also be moved to settings if they vary per device)
  static const String mqttPublishTopic = 'device/C97F0007E/cmd';
  static const String mqttSubscribeTopic = 'device/C97F0007E/state';
}
