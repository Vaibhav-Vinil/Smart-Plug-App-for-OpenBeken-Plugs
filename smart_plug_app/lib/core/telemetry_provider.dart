import 'dart:async';
import 'package:flutter/material.dart';
import 'connection_manager.dart';
import 'api_service.dart';
import 'mqtt_service.dart';
import 'settings_service.dart';
import 'discovery_service.dart';
import 'config.dart';

class TelemetryData {
  double voltage;
  double current;
  double power;
  double energyTotal;
  double energyToday;
  double chipTemp;
  int rssi;
  bool isRelayOn;

  TelemetryData({
    this.voltage = 0.0,
    this.current = 0.0,
    this.power = 0.0,
    this.energyTotal = 0.0,
    this.energyToday = 0.0,
    this.chipTemp = 0.0,
    this.rssi = 0,
    this.isRelayOn = false,
  });

  factory TelemetryData.fromJson(Map<String, dynamic> json) {
    double getDbl(Map<String, dynamic>? obj, String key, [double def = 0.0]) {
      if (obj != null && obj.containsKey(key) && obj[key] != null) {
        var val = obj[key];
        if (val is num) return val.toDouble();
        if (val is String) return double.tryParse(val) ?? def;
      }
      return def;
    }

    Map<String, dynamic>? statusSns =
        json['StatusSNS'] as Map<String, dynamic>?;
    Map<String, dynamic>? status = json['Status'] as Map<String, dynamic>?;

    Map<String, dynamic>? energy;
    if (statusSns != null && statusSns.containsKey('ENERGY')) {
      energy = statusSns['ENERGY'] as Map<String, dynamic>?;
    } else if (statusSns != null && statusSns.containsKey('Energy')) {
      energy = statusSns['Energy'] as Map<String, dynamic>?;
    } else if (status != null && status.containsKey('Energy')) {
      energy = status['Energy'] as Map<String, dynamic>?;
    } else if (json.containsKey('EnergyStatus')) {
      var es = json['EnergyStatus'];
      if (es is Map<String, dynamic>) {
        energy = es.containsKey('Energy')
            ? es['Energy'] as Map<String, dynamic>
            : es;
      }
    }

    Map<String, dynamic>? esp32 = statusSns != null
        ? statusSns['ESP32'] as Map<String, dynamic>?
        : null;
    Map<String, dynamic>? statusSts =
        json['StatusSTS'] as Map<String, dynamic>?;
    Map<String, dynamic>? wifi = statusSts != null
        ? statusSts['Wifi'] as Map<String, dynamic>?
        : null;

    double chipTemp = getDbl(
      esp32,
      'Temperature',
      getDbl(
        statusSns,
        'Temperature',
        getDbl(json, 'Temperature', getDbl(statusSts, 'Temperature')),
      ),
    );

    return TelemetryData(
      voltage: getDbl(energy, 'Voltage', getDbl(json, 'Voltage')),
      current: getDbl(energy, 'Current', getDbl(json, 'Current')),
      power: getDbl(energy, 'Power', getDbl(json, 'Power')),
      energyTotal: getDbl(
        energy,
        'ConsumptionTotal',
        getDbl(energy, 'Total', getDbl(json, 'EnergyTotal')),
      ),
      energyToday: getDbl(energy, 'Today', getDbl(json, 'EnergyToday')),
      chipTemp: chipTemp,
      rssi: getDbl(wifi, 'RSSI', getDbl(json, 'RSSI')).toInt(),
      isRelayOn:
          json['POWER'] == 'ON' ||
          json['POWER1'] == 'ON' ||
          (statusSts != null && statusSts['POWER'] == 'ON') ||
          json['Power'] == 1 ||
          json['POWER'] == 1 ||
          json['POWER1'] == 1 ||
          json['POWER'] == '1' ||
          json['POWER1'] == '1',
    );
  }
}

class TelemetryProvider extends ChangeNotifier {
  final ConnectionManager connectionManager;
  final SettingsService settingsService;
  final DiscoveryService discoveryService;

  late final ApiService _apiService;
  final MqttService _mqttService = MqttService();

  TelemetryData _data = TelemetryData();
  TelemetryData get data => _data;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDisconnected = true;
  bool get isDisconnected => _isDisconnected;

  // Fallback: If "dubai-plug-test-123/1/set" doesn't work, try "dubai-plug-test-123/cmnd/POWER"
  String get activePublishTopic =>
      connectionManager.currentMode == ConnectionMode.global
      ? "dubai-plug-test-123/1/set"
      : SecretConfig.mqttPublishTopic;

  String get activeSubscribeTopic =>
      connectionManager.currentMode == ConnectionMode.global
      ? "dubai-plug-test-123/1/state"
      : SecretConfig.mqttSubscribeTopic;

  String firmwareVersion = 'Unknown';
  String macAddress = 'Unknown';
  String ipAddress = 'Unknown';

  final List<double> powerHistory = [];
  Timer? _pollingTimer;

  TelemetryProvider(
    this.connectionManager,
    this.settingsService,
    this.discoveryService,
  ) {
    _apiService = ApiService(ip: settingsService.plugIpAddress);
    connectionManager.addListener(_onConnectionChanged);
    settingsService.addListener(_onSettingsChanged);
    _mqttService.onTelemetryReceived = _onMqttDataReceived;
    _onConnectionChanged();
  }

  void _onSettingsChanged() {
    _apiService.updateIp(settingsService.plugIpAddress);

    // If setup is no longer complete (device deleted), clear stale data
    if (!settingsService.isSetupComplete) {
      resetData();
    }

    if (connectionManager.currentMode == ConnectionMode.remote ||
        connectionManager.currentMode == ConnectionMode.global) {
      _startMqttConnection();
    }
  }

  void resetData() {
    _data = TelemetryData();
    powerHistory.clear();
    firmwareVersion = 'Unknown';
    macAddress = 'Unknown';
    ipAddress = 'Unknown';
    _isDisconnected = true;
    notifyListeners();
  }

  void _onConnectionChanged() {
    _pollingTimer?.cancel();
    if (connectionManager.currentMode == ConnectionMode.local) {
      _mqttService.disconnect();
      _startLocalPolling();
    } else if (connectionManager.currentMode == ConnectionMode.remote ||
        connectionManager.currentMode == ConnectionMode.global) {
      _startMqttConnection();
    }
  }

  void _startLocalPolling() {
    _fetchLocalData();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchLocalData(),
    );
  }

  Future<void> _fetchLocalData() async {
    final jsonData = await _apiService.fetchStatus();
    if (jsonData != null) {
      _isDisconnected = false;
      _data = TelemetryData.fromJson(jsonData);

      if (jsonData.containsKey('StatusNET')) {
        macAddress = jsonData['StatusNET']['Mac'] ?? macAddress;
        ipAddress = jsonData['StatusNET']['IPAddress'] ?? ipAddress;
      }
      if (jsonData.containsKey('StatusFWR')) {
        firmwareVersion = jsonData['StatusFWR']['Version'] ?? firmwareVersion;
      }

      _updateHistory(_data.power);
      notifyListeners();
    } else {
      _isDisconnected = true;
      // Trigger background discovery if unreachable in local mode and WiFi is active
      if (connectionManager.currentMode == ConnectionMode.local &&
          connectionManager.isWifiConnected &&
          !discoveryService.isScanning) {
        discoveryService.startDiscovery().then((_) {
          // Allow some time for discovery to find devices
          Future.delayed(const Duration(seconds: 8), () {
            if (discoveryService.discoveredDevices.isNotEmpty) {
              // Look for obkN device specifically if possible, otherwise first match
              final device = discoveryService.discoveredDevices.firstWhere(
                (d) => d.name.toLowerCase().contains('obkn'),
                orElse: () => discoveryService.discoveredDevices.first,
              );

              debugPrint(
                'Auto-discovered device: ${device.name} at ${device.ip}',
              );
              settingsService.setPlugIpAddress(device.ip);
            }
            discoveryService.stopDiscovery();
          });
        });
      }
      notifyListeners();
    }
  }

  Future<void> _startMqttConnection() async {
    final isGlobal = connectionManager.currentMode == ConnectionMode.global;
    // edit thisfor cloudfare
    final host = isGlobal
        ? 'wss://gives-bucks-dover-ent.trycloudflare.com/mqtt'
        : settingsService.mqttBrokerHost;
    final port = isGlobal ? 443 : SecretConfig.mqttBrokerPort;

    final connected = await _mqttService.connect(
      host: host,
      username: settingsService.mqttUsername,
      password: settingsService.mqttPassword,
      useWebSocket: isGlobal,
      port: port,
      secure:
          false, // CRITICAL: must be false for WebSockets in mqtt_client, wss:// handles security
      subscribeTopic: activeSubscribeTopic,
    );
    _isDisconnected = !connected;
    notifyListeners();
  }

  void _onMqttDataReceived(Map<String, dynamic> jsonData) {
    _isDisconnected = false;
    _data = TelemetryData.fromJson(jsonData);
    _updateHistory(_data.power);
    notifyListeners();
  }

  void _updateHistory(double power) {
    powerHistory.add(power);
    if (powerHistory.length > 50) {
      powerHistory.removeAt(0);
    }
  }

  Future<void> togglePower() async {
    _isLoading = true;
    notifyListeners();

    if (connectionManager.currentMode == ConnectionMode.local) {
      await _apiService.togglePower();
      await Future.delayed(const Duration(milliseconds: 500));
      await _fetchLocalData();
    } else if (connectionManager.currentMode == ConnectionMode.remote) {
      _mqttService.publishCommand('toggle');
    } else if (connectionManager.currentMode == ConnectionMode.global) {
      final payload = _data.isRelayOn ? '0' : '1';
      _data.isRelayOn = !_data.isRelayOn; // Optimistic update
      _mqttService.publishCommand(payload, topic: activePublishTopic);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> turnOff() async {
    _isLoading = true;
    notifyListeners();

    if (connectionManager.currentMode == ConnectionMode.local) {
      await _apiService.turnOff();
      await Future.delayed(const Duration(milliseconds: 500));
      await _fetchLocalData();
    } else if (connectionManager.currentMode == ConnectionMode.remote) {
      _mqttService.turnOff();
    } else if (connectionManager.currentMode == ConnectionMode.global) {
      _data.isRelayOn = false; // Optimistic update
      _mqttService.publishCommand('0', topic: activePublishTopic);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> turnOn() async {
    _isLoading = true;
    notifyListeners();

    if (connectionManager.currentMode == ConnectionMode.local) {
      await _apiService.turnOn();
      await Future.delayed(const Duration(milliseconds: 500));
      await _fetchLocalData();
    } else if (connectionManager.currentMode == ConnectionMode.remote) {
      _mqttService.publishCommand('on');
    } else if (connectionManager.currentMode == ConnectionMode.global) {
      _data.isRelayOn = true; // Optimistic update
      _mqttService.publishCommand('1', topic: activePublishTopic);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setDeviceSchedule(int seconds, bool turnOnAction) async {
    _isLoading = true;
    notifyListeners();

    final actionStr = turnOnAction ? 'ON' : 'OFF';
    // Format: backlog delay_s <seconds>; Power <ON/OFF>
    final command = 'backlog delay_s $seconds; Power $actionStr';

    if (connectionManager.currentMode == ConnectionMode.local) {
      await _apiService.sendRawCommand(command);
    } else if (connectionManager.currentMode == ConnectionMode.remote) {
      _mqttService.publishCommand(command);
    } else if (connectionManager.currentMode == ConnectionMode.global) {
      _mqttService.publishCommand(command, topic: activePublishTopic);
    }

    // Give some time for the device to process before fetching state
    await Future.delayed(const Duration(milliseconds: 500));
    if (connectionManager.currentMode == ConnectionMode.local) {
      await _fetchLocalData();
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    connectionManager.removeListener(_onConnectionChanged);
    settingsService.removeListener(_onSettingsChanged);
    _pollingTimer?.cancel();
    _mqttService.disconnect();
    super.dispose();
  }
}
