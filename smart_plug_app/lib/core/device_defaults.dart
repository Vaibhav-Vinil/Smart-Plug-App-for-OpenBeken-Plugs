/// Firmware / protocol defaults shared by all OpenBeken devices.
/// These are not tied to a specific home network or deployment.
class DeviceDefaults {
  /// IP used while the plug is in Wi‑Fi AP provisioning mode (OpenBeken standard).
  static const String openBekenProvisioningIp = '192.168.4.1';

  static const String httpPort = '80';
  static const int mqttTcpPort = 1883;
  static const int mqttWssPort = 443;
  static const String mqttClientIdPrefix = 'smart_plug_app';
}
