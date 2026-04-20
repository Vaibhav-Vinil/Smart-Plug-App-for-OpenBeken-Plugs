class SecretConfig {
  // Network Config
  static const String localSsid = 'Arnav2011-EXT';
  static const String plugIpAddress = '192.168.1.106';
  static const String localHttpPort = '80';

  // MQTT Config
  static const String mqttBrokerHost =
      '192.168.0.99'; // Placeholder, user will change it
  static const int mqttBrokerPort = 1883;
  static const String mqttClientId = 'flutter_client_001';
  static const String mqttUsername = 'admin'; // Placeholder
  static const String mqttPassword = 'password'; // Placeholder

  // MQTT Topics
  static const String mqttPublishTopic = 'device/C97F0007E/cmd';
  static const String mqttSubscribeTopic = 'device/C97F0007E/state';
}
