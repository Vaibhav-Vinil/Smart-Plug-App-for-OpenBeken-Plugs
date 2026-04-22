import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyPlugIp = 'plug_ip_address';
  static const String _keyLocalSsid = 'local_ssid';
  static const String _keyMqttHost = 'mqtt_broker_host';
  static const String _keyMqttUser = 'mqtt_username';
  static const String _keyMqttPass = 'mqtt_password';
  static const String _keyIsSetupComplete = 'is_setup_complete';
  static const String _keyIsGlobalModeEnabled = 'is_global_mode_enabled';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  String get plugIpAddress => _prefs.getString(_keyPlugIp) ?? '192.168.1.106';
  String get localSsid => _prefs.getString(_keyLocalSsid) ?? 'Arnav2011-EXT';
  String get mqttBrokerHost => _prefs.getString(_keyMqttHost) ?? '192.168.0.99';
  String get mqttUsername => _prefs.getString(_keyMqttUser) ?? 'admin';
  String get mqttPassword => _prefs.getString(_keyMqttPass) ?? 'password';
  bool get isSetupComplete => _prefs.getBool(_keyIsSetupComplete) ?? false;
  bool get isGlobalModeEnabled => _prefs.getBool(_keyIsGlobalModeEnabled) ?? false;

  Future<void> setPlugIpAddress(String value) async {
    await _prefs.setString(_keyPlugIp, value);
    notifyListeners();
  }

  Future<void> setLocalSsid(String value) async {
    await _prefs.setString(_keyLocalSsid, value);
    notifyListeners();
  }

  Future<void> setMqttConfig({
    String? host,
    String? user,
    String? pass,
  }) async {
    if (host != null) await _prefs.setString(_keyMqttHost, host);
    if (user != null) await _prefs.setString(_keyMqttUser, user);
    if (pass != null) await _prefs.setString(_keyMqttPass, pass);
    notifyListeners();
  }

  Future<void> setSetupComplete(bool value) async {
    await _prefs.setBool(_keyIsSetupComplete, value);
    notifyListeners();
  }

  Future<void> setGlobalMode(bool value) async {
    await _prefs.setBool(_keyIsGlobalModeEnabled, value);
    notifyListeners();
  }

  Future<void> saveSettings({
    required String ip,
    required String ssid,
    String? mqttHost,
    String? mqttUser,
    String? mqttPass,
  }) async {
    await _prefs.setString(_keyPlugIp, ip);
    await _prefs.setString(_keyLocalSsid, ssid);
    if (mqttHost != null) await _prefs.setString(_keyMqttHost, mqttHost);
    if (mqttUser != null) await _prefs.setString(_keyMqttUser, mqttUser);
    if (mqttPass != null) await _prefs.setString(_keyMqttPass, mqttPass);
    await _prefs.setBool(_keyIsSetupComplete, true);
    notifyListeners();
  }
  
  Future<void> deleteCurrentDevice() async {
    await _prefs.remove(_keyPlugIp);
    await _prefs.setBool(_keyIsSetupComplete, false);
    notifyListeners();
  }

  Future<void> reset() async {
    await _prefs.clear();
    notifyListeners();
  }
}
