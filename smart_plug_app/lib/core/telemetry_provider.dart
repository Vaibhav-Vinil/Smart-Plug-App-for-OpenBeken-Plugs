import 'dart:async';
import 'package:flutter/material.dart';
import 'connection_manager.dart';
import 'api_service.dart';
import 'mqtt_service.dart';

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
    // Helper to safely extract double
    double getDbl(Map<String, dynamic>? obj, String key, [double def = 0.0]) {
      if (obj != null && obj.containsKey(key) && obj[key] != null) {
        var val = obj[key];
        if (val is num) return val.toDouble();
        if (val is String) return double.tryParse(val) ?? def;
      }
      return def;
    }

    Map<String, dynamic>? statusSns = json['StatusSNS'] as Map<String, dynamic>?;
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
        energy = es.containsKey('Energy') ? es['Energy'] as Map<String, dynamic> : es;
      }
    }

    Map<String, dynamic>? esp32 = statusSns != null ? statusSns['ESP32'] as Map<String, dynamic>? : null;

    Map<String, dynamic>? statusSts = json['StatusSTS'] as Map<String, dynamic>?;
    Map<String, dynamic>? wifi = statusSts != null ? statusSts['Wifi'] as Map<String, dynamic>? : null;

    double chipTemp = getDbl(esp32, 'Temperature', getDbl(statusSns, 'Temperature', getDbl(json, 'Temperature', getDbl(statusSts, 'Temperature'))));

    return TelemetryData(
      voltage: getDbl(energy, 'Voltage', getDbl(json, 'Voltage')),
      current: getDbl(energy, 'Current', getDbl(json, 'Current')),
      power: getDbl(energy, 'Power', getDbl(json, 'Power')),
      energyTotal: getDbl(energy, 'ConsumptionTotal', getDbl(energy, 'Total', getDbl(json, 'EnergyTotal'))),
      energyToday: getDbl(energy, 'Today', getDbl(json, 'EnergyToday')),
      chipTemp: chipTemp,
      rssi: getDbl(wifi, 'RSSI', getDbl(json, 'RSSI')).toInt(),
      isRelayOn: json['POWER'] == 'ON' || (statusSts != null && statusSts['POWER'] == 'ON') || json['Power'] == 1 || json['POWER'] == 1 || json['POWER'] == '1' || json['POWER'] == '1',
    );
  }
}

class TelemetryProvider extends ChangeNotifier {
  final ConnectionManager connectionManager;
  final ApiService _apiService = ApiService();
  final MqttService _mqttService = MqttService();

  TelemetryData _data = TelemetryData();
  TelemetryData get data => _data;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDisconnected = true;
  bool get isDisconnected => _isDisconnected;

  String firmwareVersion = 'Unknown';
  String macAddress = 'Unknown';
  String ipAddress = 'Unknown';

  // In-memory historical buffer for the LineChart
  final List<double> powerHistory = [];

  Timer? _pollingTimer;

  TelemetryProvider(this.connectionManager) {
    connectionManager.addListener(_onConnectionChanged);
    _mqttService.onTelemetryReceived = _onMqttDataReceived;
    _onConnectionChanged(); // initial check
  }

  void _onConnectionChanged() {
    _pollingTimer?.cancel();
    if (connectionManager.currentMode == ConnectionMode.local) {
      _mqttService.disconnect();
      _startLocalPolling();
    } else if (connectionManager.currentMode == ConnectionMode.remote) {
      _startMqttConnection();
    }
  }

  void _startLocalPolling() {
    _fetchLocalData();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchLocalData());
  }

  Future<void> _fetchLocalData() async {
    final jsonData = await _apiService.fetchStatus();
    if (jsonData != null) {
      _isDisconnected = false;
      _data = TelemetryData.fromJson(jsonData);
      
      // Parse device metadata if present in StatusNET or StatusFWR
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
       notifyListeners();
    }
  }

  Future<void> _startMqttConnection() async {
    final connected = await _mqttService.connect();
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
    // Keep last 60 plot points (e.g. 5 mins of 5s resolution, or more to fit charting visually well)
    if (powerHistory.length > 50) {
      powerHistory.removeAt(0);
    }
  }

  Future<void> togglePower() async {
    _isLoading = true;
    notifyListeners();

    if (connectionManager.currentMode == ConnectionMode.local) {
      await _apiService.togglePower();
      // Fast refresh assumption
      await Future.delayed(const Duration(milliseconds: 500));
      await _fetchLocalData();
    } else if (connectionManager.currentMode == ConnectionMode.remote) {
      _mqttService.publishCommand('toggle');
      // Assuming MQTT receives updated feedback over state topic shortly.
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
    }

    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    connectionManager.removeListener(_onConnectionChanged);
    _pollingTimer?.cancel();
    _mqttService.disconnect();
    super.dispose();
  }
}
