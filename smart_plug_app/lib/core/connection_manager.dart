import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  bool get isWifiConnected => _currentMode != ConnectionMode.offline && _currentSsid != null;

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

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> requestPermissions() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    if (settingsService.isGlobalModeEnabled) {
      _currentMode = ConnectionMode.global;
      _currentSsid = null;
      notifyListeners();
      return;
    }

    if (results.contains(ConnectivityResult.none)) {
      _currentMode = ConnectionMode.offline;
      _currentSsid = null;
    } else if (results.contains(ConnectivityResult.wifi)) {
      try {
        _currentSsid = await _networkInfo.getWifiName();
        final ssid = _currentSsid?.replaceAll('"', '');
        
        // Use SSID from SettingsService
        if (ssid == settingsService.localSsid || ssid == 'AndroidWifi') {
          _currentMode = ConnectionMode.local;
        } else {
          _currentMode = ConnectionMode.remote;
        }
      } catch (e) {
        debugPrint('Error getting WiFi name: $e');
        _currentMode = ConnectionMode.remote;
      }
    } else {
      _currentMode = ConnectionMode.remote;
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
