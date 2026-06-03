import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connection_manager.dart';
import 'api_service.dart';
import 'mqtt_service.dart';
import 'settings_service.dart';
import 'discovery_service.dart';
import 'device_config_parser.dart';
import 'device_defaults.dart';

class TelemetryData {
  double voltage;
  double current;
  double power;
  double energyTotal;
  double energyToday;
  double energyYesterday;
  double energy2DaysAgo;
  double energy3DaysAgo;
  double chipTemp;
  int rssi;
  bool isRelayOn;

  TelemetryData({
    this.voltage = 0.0,
    this.current = 0.0,
    this.power = 0.0,
    this.energyTotal = 0.0,
    this.energyToday = 0.0,
    this.energyYesterday = 0.0,
    this.energy2DaysAgo = 0.0,
    this.energy3DaysAgo = 0.0,
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
      energyYesterday: getDbl(energy, 'Yesterday', getDbl(json, 'EnergyYesterday')),
      energy2DaysAgo: getDbl(json, 'Energy2DaysAgo'),
      energy3DaysAgo: getDbl(json, 'Energy3DaysAgo'),
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

  bool _hasLiveData = false;
  bool get hasLiveData => _hasLiveData;

  String get activePublishTopic =>
      connectionManager.currentMode == ConnectionMode.global
          ? settingsService.mqttPublishTopicGlobal
          : settingsService.mqttPublishTopicRemote;

  String get activeSubscribeTopic =>
      connectionManager.currentMode == ConnectionMode.global
          ? settingsService.mqttSubscribeTopicGlobal
          : settingsService.mqttSubscribeTopicRemote;

  String firmwareVersion = 'Unknown';
  String macAddress = 'Unknown';
  String ipAddress = 'Unknown';

  final List<MapEntry<double, double>> powerHistory = [];
  String _selectedRange = '1h';
  String get selectedRange => _selectedRange;
  // Energy used today = total - yesterday (midnight‑to‑now)
  // Compute today's energy in Wh: total is stored as kWh, convert to Wh then subtract yesterday's Wh
  double get energyTodayComputed => ((_data.energyTotal * 1000) - _data.energyYesterday).clamp(0.0, double.infinity);
  Timer? _pollingTimer;
  static const String _historyKey = 'power_history_v2';

  TelemetryProvider(
    this.connectionManager,
    this.settingsService,
    this.discoveryService,
  ) {
    _apiService = ApiService(ip: settingsService.plugIpAddress.isNotEmpty
        ? settingsService.plugIpAddress
        : '0.0.0.0');
    connectionManager.addListener(_onConnectionChanged);
    settingsService.addListener(_onSettingsChanged);
    _mqttService.onTelemetryReceived = _onMqttDataReceived;
    _loadHistory();
    _onConnectionChanged();
  }

  void updateHistoryRange(String range) {
    _selectedRange = range;
    if (_mqttService.isConnected &&
        connectionManager.currentMode == ConnectionMode.global &&
        settingsService.hasMqttTopicPrefix) {
      _mqttService.publishCommand(
        json.encode({'range': range}),
        topic: settingsService.mqttHistoryRequestTopic,
      );
    }
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_historyKey);
      if (saved != null) {
        powerHistory.clear();
        for (var s in saved) {
          final parts = s.split(':');
          if (parts.length == 2) {
            powerHistory.add(MapEntry(double.tryParse(parts[0]) ?? 0.0, double.tryParse(parts[1]) ?? 0.0));
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _historyKey,
        powerHistory.map((e) => '${e.key}:${e.value}').toList(),
      );
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  void _onSettingsChanged() {
    _apiService.updateIp(settingsService.plugIpAddress);

    // If setup is no longer complete (device deleted), clear stale data
    if (!settingsService.isSetupComplete) {
      resetData();
      return;
    }

    // Re-bind polling/MQTT when IP or connection mode changes after setup.
    _onConnectionChanged();
  }

  void resetData() {
    _data = TelemetryData();
    powerHistory.clear();
    _saveHistory();
    firmwareVersion = 'Unknown';
    macAddress = 'Unknown';
    ipAddress = 'Unknown';
    _isDisconnected = true;
    _hasLiveData = false;
    notifyListeners();
  }

  void _onConnectionChanged() {
    _pollingTimer?.cancel();
    if (connectionManager.currentMode == ConnectionMode.local &&
        settingsService.hasPlugIp) {
      _mqttService.disconnect();
      _startLocalPolling();
    } else if (connectionManager.currentMode == ConnectionMode.remote ||
        connectionManager.currentMode == ConnectionMode.global) {
      _startMqttConnection();
      if (connectionManager.currentMode == ConnectionMode.global) {
        _startMqttPolling();
      }
    } else {
      _mqttService.disconnect();
      _isDisconnected = true;
      notifyListeners();
    }
  }

  void _startMqttPolling() {
    if (!settingsService.hasMqttTopicPrefix) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_mqttService.isConnected) {
        _mqttService.publishCommand('', topic: settingsService.mqttTopic('energycounter_today/get'));
        _mqttService.publishCommand('', topic: settingsService.mqttTopic('energycounter_yesterday/get'));
        _mqttService.publishCommand('', topic: settingsService.mqttTopic('energycounter_2_days_ago/get'));
        _mqttService.publishCommand('', topic: settingsService.mqttTopic('energycounter_3_days_ago/get'));
        _mqttService.publishCommand('', topic: settingsService.mqttTopic('power/get'));
        _mqttService.publishCommand('', topic: settingsService.mqttTopic('voltage/get'));
      }
    });
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
      _hasLiveData = true;
      _data = TelemetryData.fromJson(jsonData);

      // Fetch extra energy history if not in StatusSNS (common in some OpenBeken versions)
      if (_data.energyYesterday == 0) {
        final yestStr = await _apiService.sendRawCommand('energycounter_yesterday');
        if (yestStr != null) {
          _data.energyYesterday = double.tryParse(yestStr) ?? 0.0;
        }
        
        final d2Str = await _apiService.sendRawCommand('energycounter_2_days_ago');
        if (d2Str != null) {
          _data.energy2DaysAgo = double.tryParse(d2Str) ?? 0.0;
        }
        
        final d3Str = await _apiService.sendRawCommand('energycounter_3_days_ago');
        if (d3Str != null) {
          _data.energy3DaysAgo = double.tryParse(d3Str) ?? 0.0;
        }
        
        // NEW: Fetch today's energy if missing
        if (_data.energyToday == 0) {
          final todayStr = await _apiService.sendRawCommand('energycounter_today');
          if (todayStr != null) {
            _data.energyToday = double.tryParse(todayStr) ?? 0.0;
          }
        }
      }

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
              final device = discoveryService.discoveredDevices.first;

              debugPrint(
                'Auto-discovered device: ${device.name} at ${device.ip}',
              );
              settingsService.setPlugIpAddress(device.ip);
              final prefix =
                  DeviceConfigParser.mqttTopicPrefixFromDeviceName(device.name);
              if (prefix != null) {
                settingsService.setMqttTopicPrefix(prefix);
              }
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

    if (!settingsService.hasMqttTopicPrefix) {
      _isDisconnected = true;
      notifyListeners();
      return;
    }

    final String host;
    final int port;
    final String subTopic;
    final String pubTopic;

    if (isGlobal) {
      if (!settingsService.hasGlobalBridge) {
        _isDisconnected = true;
        notifyListeners();
        return;
      }
      
      String rawUrl = settingsService.globalBridgeUrl.trim();
        // Remove any http:// or https:// prefix that the user might have entered
        rawUrl = rawUrl.replaceFirst(RegExp(r'^https?://'), '');
        // Ensure the URL uses the WebSocket secure scheme
        if (!rawUrl.startsWith('ws://') && !rawUrl.startsWith('wss://')) {
          rawUrl = 'wss://$rawUrl';
        }
        // Ensure the path ends with /mqtt
        if (!rawUrl.endsWith('/mqtt')) {
          if (rawUrl.endsWith('/')) {
            rawUrl = '${rawUrl}mqtt';
          } else {
            rawUrl = '$rawUrl/mqtt';
          }
        }
        
        host = rawUrl;
        port = DeviceDefaults.mqttWssPort;
      subTopic = settingsService.mqttSubscribeTopicGlobal;
      pubTopic = settingsService.mqttPublishTopicGlobal;
    } else {
      if (!settingsService.hasMqttBroker) {
        _isDisconnected = true;
        notifyListeners();
        return;
      }
      host = settingsService.mqttBrokerHost;
      port = settingsService.mqttBrokerPort;
      subTopic = settingsService.mqttSubscribeTopicRemote;
      pubTopic = settingsService.mqttPublishTopicRemote;
    }

    if (subTopic.isEmpty || pubTopic.isEmpty) {
      _isDisconnected = true;
      notifyListeners();
      return;
    }

    final connected = await _mqttService.connect(
      host: host,
      username: settingsService.mqttUsername,
      password: settingsService.mqttPassword,
      useWebSocket: isGlobal,
      port: port,
      secure: false,
      subscribeTopic: subTopic,
      defaultPublishTopic: pubTopic,
    );

    if (connected && isGlobal) {
      _mqttService.publishCommand(
        json.encode({'range': _selectedRange}),
        topic: settingsService.mqttHistoryRequestTopic,
      );
    }

    _isDisconnected = !connected;
    notifyListeners();
  }

  void _onMqttDataReceived(String topic, String payload) {
    _isDisconnected = false;
    _hasLiveData = true;
    debugPrint('MQTT Received: $topic -> $payload');
    
    try {
      if (topic == settingsService.mqttHistoryResponseTopic) {
        final List<dynamic> bulk = json.decode(payload);
        powerHistory.clear();
        for (var item in bulk) {
          if (item is List && item.length == 2) {
            powerHistory.add(MapEntry((item[0] as num).toDouble(), (item[1] as num).toDouble()));
          }
        }
        _saveHistory();
        debugPrint('Loaded ${powerHistory.length} history points from recorder');
      } else if (topic.endsWith('/state') || topic.endsWith('/tele/SENSOR')) {
        final data = json.decode(payload);
        _data = TelemetryData.fromJson(data);
        _updateHistory(_data.power);
      } else if (topic.contains('voltage')) {
        _data.voltage = double.tryParse(payload) ?? _data.voltage;
      } else if (topic.contains('current')) {
        _data.current = double.tryParse(payload) ?? _data.current;
      } else if (topic.contains('power') && !topic.contains('power_')) {
        // Match "power" or "power/get" but not "power_factor"
        _data.power = double.tryParse(payload) ?? _data.power;
        _updateHistory(_data.power);
      } else if (topic.contains('energycounter_today')) {
        _data.energyToday = double.tryParse(payload) ?? _data.energyToday;
      } else if (topic.contains('energycounter_yesterday')) {
        _data.energyYesterday = double.tryParse(payload) ?? _data.energyYesterday;
      } else if (topic.contains('energycounter_2_days_ago')) {
        _data.energy2DaysAgo = double.tryParse(payload) ?? _data.energy2DaysAgo;
      } else if (topic.contains('energycounter_3_days_ago')) {
        _data.energy3DaysAgo = double.tryParse(payload) ?? _data.energy3DaysAgo;
      } else if (topic.endsWith('/1/get') ||
          topic.endsWith('/1/state') ||
          topic.endsWith('/POWER/get') ||
          topic.endsWith('/POWER')) {
        final p = payload.trim().toUpperCase();
        _data.isRelayOn = p == '1' || p == 'ON';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing MQTT data: $e');
    }
  }

  void _updateHistory(double power) {
    powerHistory.add(MapEntry(DateTime.now().millisecondsSinceEpoch / 1000.0, power));
    if (powerHistory.length > 1000) {
      powerHistory.removeAt(0);
    }
    _saveHistory();
  }

  Future<void> togglePower() async {
    _isLoading = true;
    notifyListeners();

    if (connectionManager.currentMode == ConnectionMode.local) {
      await _apiService.togglePower();
      await Future.delayed(const Duration(milliseconds: 500));
      await _fetchLocalData();
    } else if (connectionManager.currentMode == ConnectionMode.remote) {
      _mqttService.publishCommand('toggle', topic: activePublishTopic);
    } else if (connectionManager.currentMode == ConnectionMode.global) {
      _data.isRelayOn = !_data.isRelayOn;
      _mqttService.publishCommand('toggle', topic: activePublishTopic);
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
      _mqttService.turnOff(topic: activePublishTopic);
    } else if (connectionManager.currentMode == ConnectionMode.global) {
      _data.isRelayOn = false;
      _mqttService.publishCommand('off', topic: activePublishTopic);
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
      _mqttService.publishCommand('on', topic: activePublishTopic);
    } else if (connectionManager.currentMode == ConnectionMode.global) {
      _data.isRelayOn = true;
      _mqttService.publishCommand('on', topic: activePublishTopic);
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
      _mqttService.publishCommand(command, topic: activePublishTopic);
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
