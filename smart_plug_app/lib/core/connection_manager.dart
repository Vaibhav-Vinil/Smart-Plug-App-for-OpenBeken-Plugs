import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_service.dart';

enum ConnectionMode { local, remote, offline, global }

class ConnectionManager extends ChangeNotifier {
  final SettingsService settingsService;
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  ConnectionMode _currentMode = ConnectionMode.offline;
  ConnectionMode get currentMode => _currentMode;

  String? _currentSsid;
  String? get currentSsid => _currentSsid;

  bool get isWifiConnected =>
      _currentMode == ConnectionMode.local ||
      (_currentSsid != null &&
          _currentMode != ConnectionMode.offline &&
          _currentMode != ConnectionMode.global);

  ConnectionManager(this.settingsService) {
    _initConnectivity();
    settingsService.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    _connectivity.checkConnectivity().then(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    await requestPermissions();
    final results = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(results);
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> requestPermissions() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    if (settingsService.isGlobalModeEnabled && settingsService.canUseGlobalMode) {
      _currentMode = ConnectionMode.global;
      _currentSsid = null;
      notifyListeners();
      return;
    }

    if (settingsService.isGlobalModeEnabled && !settingsService.canUseGlobalMode) {
      await settingsService.setGlobalMode(false);
    }

    if (results.contains(ConnectivityResult.none)) {
      _currentMode = ConnectionMode.offline;
      _currentSsid = null;
    } else if (results.contains(ConnectivityResult.wifi)) {
      try {
        _currentSsid = await _networkInfo.getWifiName();
      } catch (e) {
        debugPrint('Error getting WiFi name: $e');
        _currentSsid = null;
      }

      if (settingsService.hasPlugIp) {
        _currentMode = ConnectionMode.local;
      } else if (settingsService.hasMqttBroker && settingsService.hasMqttTopicPrefix) {
        _currentMode = ConnectionMode.remote;
      } else {
        _currentMode = ConnectionMode.offline;
      }
    } else if (settingsService.hasMqttBroker && settingsService.hasMqttTopicPrefix) {
      _currentMode = ConnectionMode.remote;
      _currentSsid = null;
    } else {
      _currentMode = ConnectionMode.offline;
      _currentSsid = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    settingsService.removeListener(_onSettingsChanged);
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
