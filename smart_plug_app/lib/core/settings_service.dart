import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_defaults.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyPlugIp = 'plug_ip_address';
  static const String _keyMqttHost = 'mqtt_broker_host';
  static const String _keyMqttPort = 'mqtt_broker_port';
  static const String _keyMqttUser = 'mqtt_username';
  static const String _keyMqttPass = 'mqtt_password';
  static const String _keyMqttTopicPrefix = 'mqtt_topic_prefix';
  static const String _keyMqttPublishTopic = 'mqtt_publish_topic';
  static const String _keyMqttSubscribeTopic = 'mqtt_subscribe_topic';
  static const String _keyGlobalBridgeUrl = 'global_bridge_url';
  static const String _keyIsSetupComplete = 'is_setup_complete';
  static const String _keyIsGlobalModeEnabled = 'is_global_mode_enabled';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  String get plugIpAddress => _prefs.getString(_keyPlugIp)?.trim() ?? '';
  bool get hasPlugIp => plugIpAddress.isNotEmpty;

  String get mqttBrokerHost => _prefs.getString(_keyMqttHost)?.trim() ?? '';
  int get mqttBrokerPort =>
      _prefs.getInt(_keyMqttPort) ?? DeviceDefaults.mqttTcpPort;
  String get mqttUsername => _prefs.getString(_keyMqttUser) ?? '';
  String get mqttPassword => _prefs.getString(_keyMqttPass) ?? '';
  bool get hasMqttBroker => mqttBrokerHost.isNotEmpty;

  String get mqttTopicPrefix => _prefs.getString(_keyMqttTopicPrefix)?.trim() ?? '';
  bool get hasMqttTopicPrefix => mqttTopicPrefix.isNotEmpty;

  String get mqttPublishTopicOverride =>
      _prefs.getString(_keyMqttPublishTopic)?.trim() ?? '';
  String get mqttSubscribeTopicOverride =>
      _prefs.getString(_keyMqttSubscribeTopic)?.trim() ?? '';

  String get globalBridgeUrl => _prefs.getString(_keyGlobalBridgeUrl)?.trim() ?? '';
  bool get hasGlobalBridge => globalBridgeUrl.isNotEmpty;

  bool get isSetupComplete => _prefs.getBool(_keyIsSetupComplete) ?? false;
  bool get isGlobalModeEnabled => _prefs.getBool(_keyIsGlobalModeEnabled) ?? false;

  bool get canUseGlobalMode => hasGlobalBridge && hasMqttTopicPrefix;

  /// OpenBeken telemetry channel, e.g. `dubai-plug-test-123/power/get`.
  String mqttTopic(String suffix) {
    final p = mqttTopicPrefix;
    if (p.isEmpty) return suffix;
    final s = suffix.startsWith('/') ? suffix.substring(1) : suffix;
    return '$p/$s';
  }

  /// OpenBeken command topic, e.g. `cmnd/dubai-plug-test-123/POWER`.
  String openBekenCmnd(String command) {
    final cmd = command.startsWith('/') ? command.substring(1) : command;
    if (!hasMqttTopicPrefix) return 'cmnd/$cmd';
    return 'cmnd/$mqttTopicPrefix/$cmd';
  }

  /// Wildcard subscription for all plug channels (`…/#`).
  String get _openBekenSubscribeWildcard =>
      hasMqttTopicPrefix ? '$mqttTopicPrefix/#' : '';

  String get mqttPublishTopicRemote {
    if (mqttPublishTopicOverride.isNotEmpty) return mqttPublishTopicOverride;
    if (hasMqttTopicPrefix) return openBekenCmnd('POWER');
    return '';
  }

  String get mqttSubscribeTopicRemote {
    if (mqttSubscribeTopicOverride.isNotEmpty) return mqttSubscribeTopicOverride;
    return _openBekenSubscribeWildcard;
  }

  String get mqttPublishTopicGlobal => mqttPublishTopicRemote;
  String get mqttSubscribeTopicGlobal => mqttSubscribeTopicRemote;
  String get mqttHistoryRequestTopic => mqttTopic('history/req');
  String get mqttHistoryResponseTopic => mqttTopic('history/res');

  Future<void> setPlugIpAddress(String value) async {
    await _prefs.setString(_keyPlugIp, value.trim());
    notifyListeners();
  }

  Future<void> setMqttTopicPrefix(String value) async {
    await _prefs.setString(_keyMqttTopicPrefix, value.trim());
    notifyListeners();
  }

  Future<void> setMqttConfig({
    String? host,
    int? port,
    String? user,
    String? pass,
    String? topicPrefix,
    String? publishTopic,
    String? subscribeTopic,
    String? globalBridgeUrl,
  }) async {
    if (host != null) await _prefs.setString(_keyMqttHost, host.trim());
    if (port != null) await _prefs.setInt(_keyMqttPort, port);
    if (user != null) await _prefs.setString(_keyMqttUser, user);
    if (pass != null) await _prefs.setString(_keyMqttPass, pass);
    if (topicPrefix != null) {
      await _prefs.setString(_keyMqttTopicPrefix, topicPrefix.trim());
    }
    if (publishTopic != null) {
      await _prefs.setString(_keyMqttPublishTopic, publishTopic.trim());
    }
    if (subscribeTopic != null) {
      await _prefs.setString(_keyMqttSubscribeTopic, subscribeTopic.trim());
    }
    if (globalBridgeUrl != null) {
      await _prefs.setString(_keyGlobalBridgeUrl, globalBridgeUrl.trim());
    }
    notifyListeners();
  }

  Future<void> setSetupComplete(bool value) async {
    await _prefs.setBool(_keyIsSetupComplete, value);
    notifyListeners();
  }

  Future<void> setGlobalMode(bool value) async {
    if (value && !canUseGlobalMode) return;
    await _prefs.setBool(_keyIsGlobalModeEnabled, value);
    notifyListeners();
  }

  Future<void> saveDeviceSettings({
    required String ip,
    String? mqttTopicPrefix,
    String? mqttHost,
    int? mqttPort,
    String? mqttUser,
    String? mqttPass,
    String? globalBridgeUrl,
  }) async {
    await _prefs.setString(_keyPlugIp, ip.trim());
    if (mqttTopicPrefix != null && mqttTopicPrefix.trim().isNotEmpty) {
      await _prefs.setString(_keyMqttTopicPrefix, mqttTopicPrefix.trim());
    }
    if (mqttHost != null) await _prefs.setString(_keyMqttHost, mqttHost.trim());
    if (mqttPort != null) await _prefs.setInt(_keyMqttPort, mqttPort);
    if (mqttUser != null) await _prefs.setString(_keyMqttUser, mqttUser);
    if (mqttPass != null) await _prefs.setString(_keyMqttPass, mqttPass);
    if (globalBridgeUrl != null) {
      await _prefs.setString(_keyGlobalBridgeUrl, globalBridgeUrl.trim());
    }
    await _prefs.setBool(_keyIsSetupComplete, true);
    notifyListeners();
  }

  Future<void> deleteCurrentDevice() async {
    await _prefs.remove(_keyPlugIp);
    await _prefs.remove(_keyMqttHost);
    await _prefs.remove(_keyMqttPort);
    await _prefs.remove(_keyMqttUser);
    await _prefs.remove(_keyMqttPass);
    await _prefs.remove(_keyMqttTopicPrefix);
    await _prefs.remove(_keyMqttPublishTopic);
    await _prefs.remove(_keyMqttSubscribeTopic);
    await _prefs.remove(_keyGlobalBridgeUrl);
    await _prefs.setBool(_keyIsSetupComplete, false);
    await _prefs.setBool(_keyIsGlobalModeEnabled, false);
    notifyListeners();
  }

  Future<void> reset() async {
    await _prefs.clear();
    notifyListeners();
  }
}
