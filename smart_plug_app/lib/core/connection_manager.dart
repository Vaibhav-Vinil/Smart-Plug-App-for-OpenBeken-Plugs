import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config.dart';

enum ConnectionMode { local, remote, offline }

class ConnectionManager extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  ConnectionMode _currentMode = ConnectionMode.offline;
  ConnectionMode get currentMode => _currentMode;

  String? _currentSsid;
  String? get currentSsid => _currentSsid;

  ConnectionManager() {
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    await requestPermissions();
    
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    await _updateConnectionStatus(results);

    // Listen for changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> requestPermissions() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> results) async {
    if (results.contains(ConnectivityResult.none)) {
      _currentMode = ConnectionMode.offline;
      _currentSsid = null;
    } else if (results.contains(ConnectivityResult.wifi)) {
      try {
        _currentSsid = await _networkInfo.getWifiName();
        // BSSID/SSID from network_info_plus is often wrapped in quotes
        final ssid = _currentSsid?.replaceAll('"', '');
        
        if (ssid == SecretConfig.localSsid || ssid == 'AndroidWifi') {
          _currentMode = ConnectionMode.local;
        } else {
          _currentMode = ConnectionMode.remote;
        }
      } catch (e) {
        debugPrint('Error getting WiFi name: $e');
        _currentMode = ConnectionMode.remote;
      }
    } else {
      // Mobile data or other networks
      _currentMode = ConnectionMode.remote;
      _currentSsid = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
