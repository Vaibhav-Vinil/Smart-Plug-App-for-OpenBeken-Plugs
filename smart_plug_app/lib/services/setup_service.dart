import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/discovery_service.dart';
import '../core/connection_manager.dart';
import '../core/settings_service.dart';
import '../core/device_config_parser.dart';
import '../core/device_defaults.dart';

enum SetupStatus {
  idle,
  provisioning,
  waitingToReconnect, // Phase 2: 15s Gap
  discovering,        // Phase 3: mDNS Scan
  discovered,         // Found & Saved
  error,
}

class SetupService extends ChangeNotifier {
  final DiscoveryService discoveryService;
  final ConnectionManager connectionManager;
  final SettingsService settingsService;
  
  SetupStatus _status = SetupStatus.idle;
  String? _statusMessage;
  int _countdown = 0;

  SetupService(this.discoveryService, this.connectionManager, this.settingsService) {
    // Coordinate discovery completion
    discoveryService.onDeviceDiscovered = _handleDeviceDiscovered;
  }

  SetupStatus get status => _status;
  String? get statusMessage => _statusMessage;
  int get countdown => _countdown;

  Future<bool> provisionDevice(String ssid, String password) async {
    _status = SetupStatus.provisioning;
    _statusMessage = 'Sending WiFi credentials...';
    notifyListeners();

    const targetIp = DeviceDefaults.openBekenProvisioningIp;

    try {
      // 1. Send WiFi credentials
      final provisionUrl = 'http://$targetIp/cfg_wifi_set?ssid=${Uri.encodeComponent(ssid)}&pass=${Uri.encodeComponent(password)}';
      await http.get(Uri.parse(provisionUrl)).timeout(const Duration(seconds: 10));
      
      // 2. Send Restart command
      final restartUrl = 'http://$targetIp/cm?cmnd=Restart';
      await http.get(Uri.parse(restartUrl)).timeout(const Duration(seconds: 5));
      
    } on SocketException {
      // Success: Connection dropped means device is rebooting
    } catch (e) {
      _status = SetupStatus.error;
      _statusMessage = 'Setup failed: $e';
      notifyListeners();
      return false;
    }

    // Phase 2: The Gap
    _status = SetupStatus.waitingToReconnect;
    _countdown = 15;
    _statusMessage = 'Connecting device to WiFi...';
    notifyListeners();

    // Start Phase 2 Countdown
    for (int i = 0; i < 15; i++) {
      await Future.delayed(const Duration(seconds: 1));
      _countdown--;
      notifyListeners();
    }

    // Phase 3: Discovery
    _status = SetupStatus.discovering;
    _statusMessage = 'Searching for your plug on the network...';
    notifyListeners();

    await discoveryService.startDiscovery();
    return true;
  }

  Future<void> startManualDiscovery() async {
    _status = SetupStatus.discovering;
    _statusMessage = 'Searching for your plug on the network...';
    notifyListeners();

    await discoveryService.startDiscovery();
  }

  void _handleDeviceDiscovered(DiscoveredDevice device) async {
    if (_status == SetupStatus.discovering) {
      // CRITICAL: Persistence before navigation
      await settingsService.setPlugIpAddress(device.ip);
      final prefix =
          DeviceConfigParser.mqttTopicPrefixFromDeviceName(device.name);
      if (prefix != null) {
        await settingsService.setMqttTopicPrefix(prefix);
      }
      await settingsService.setSetupComplete(true);
      
      _status = SetupStatus.discovered;
      _statusMessage = 'Magic moment! Found ${device.name}';
      notifyListeners();
    }
  }

  void resetStatus() {
    _status = SetupStatus.idle;
    _statusMessage = null;
    notifyListeners();
  }
}
