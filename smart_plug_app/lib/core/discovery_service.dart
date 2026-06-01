import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:upnp_client/upnp_client.dart' as upnp;
import 'package:flutter_multicast_lock/flutter_multicast_lock.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

class DiscoveredDevice {
  final String name;
  final String host;
  final int port;
  final String ip;

  DiscoveredDevice({
    required this.name,
    required this.host,
    required this.port,
    required this.ip,
  });

  @override
  String toString() => 'DiscoveredDevice(name: $name, ip: $ip)';
}

class DiscoveryService extends ChangeNotifier {
  BonsoirDiscovery? _mdnsDiscovery;
  upnp.DeviceDiscoverer? _ssdpDiscoverer;
  final FlutterMulticastLock _multicastLock = FlutterMulticastLock();
  
  final List<DiscoveredDevice> _discoveredDevices = [];
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String? _errorMessage;
  
  // Callback for real-time discovery events
  void Function(DiscoveredDevice)? onDeviceDiscovered;

  List<DiscoveredDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  bool get isScanning => _isScanning;
  double get scanProgress => _scanProgress;
  String? get errorMessage => _errorMessage;

  Future<void> startDiscovery() async {
    if (_isScanning) return;

    await _teardownDiscovery();

    _discoveredDevices.clear();
    _isScanning = true;
    _scanProgress = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      await _multicastLock.acquireMulticastLock();
      debugPrint('Multicast Lock acquired');
    } catch (e) {
      debugPrint('Warning: Could not acquire Multicast Lock: $e');
    }

    _startMdnsDiscovery();
    _startSsdpDiscovery();
    await _startSubnetScan();
  }

  Future<void> _startMdnsDiscovery() async {
    try {
      _mdnsDiscovery = BonsoirDiscovery(type: '_http._tcp');
      await _mdnsDiscovery!.initialize();

      _mdnsDiscovery!.eventStream!.listen((event) async {
        if (event is BonsoirDiscoveryServiceFoundEvent) {
          final service = event.service;
          if (service != null && service.name.toLowerCase().contains('obk')) {
            await service.resolve(_mdnsDiscovery!.serviceResolver);
          }
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          final service = event.service;
          if (service != null && service.host != null) {
            _addDevice(
              name: service.name,
              host: service.host!,
              port: service.port,
              ip: service.host!,
            );
          }
        }
      });

      await _mdnsDiscovery!.start();
    } catch (e) {
      debugPrint('mDNS Discovery Error: $e');
    }
  }

  Future<void> _startSsdpDiscovery() async {
    try {
      _ssdpDiscoverer = upnp.DeviceDiscoverer();
      await _ssdpDiscoverer!.start(addressTypes: [InternetAddressType.IPv4]);
      
      // SSDP usually responds with XML location
      _ssdpDiscoverer!.devices.listen((device) {
        final String? friendlyName = device.description?.friendlyName;
        final String? location = device.url;

        if (location != null && friendlyName != null) {
          // Check for obk prefix in friendly name
          if (friendlyName.toLowerCase().contains('obk') || friendlyName.toLowerCase().contains('openbk')) {
            final uri = Uri.parse(location);
            final String host = uri.host;
            
            _addDevice(
              name: friendlyName,
              host: host,
              port: uri.port,
              ip: host,
            );
          }
        }
      });

      // getDevices triggers the internal search broadcast
      _ssdpDiscoverer!.getDevices(timeout: const Duration(seconds: 5));
    } catch (e) {
      debugPrint('SSDP Discovery Error: $e');
    }
  }

  Future<void> _startSubnetScan() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      
      if (wifiIP == null) {
        _errorMessage =
            'Could not detect local IP. Please ensure Location Permissions are enabled and you are connected to WiFi.';
        notifyListeners();
        await _completeDiscovery();
        return;
      }

      final String subnet = wifiIP.substring(0, wifiIP.lastIndexOf('.'));
      debugPrint('Starting Subnet Scan on $subnet.x');

      // Chunked scan: 20 IPs at a time
      const chunkSize = 20;
      for (int i = 1; i <= 254; i += chunkSize) {
        if (!_isScanning) break;

        final List<Future<void>> chunk = [];
        for (int j = i; j < i + chunkSize && j <= 254; j++) {
          final ip = '$subnet.$j';
          chunk.add(_probeIp(ip));
        }

        await Future.wait(chunk);
        
        _scanProgress = i / 254;
        notifyListeners();
      }
      
      _scanProgress = 1.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Subnet Scan Error: $e');
    } finally {
      await _completeDiscovery();
    }
  }

  Future<void> _probeIp(String ip) async {
    try {
      // 1. Quick port check
      final socket = await Socket.connect(ip, 80, timeout: const Duration(milliseconds: 300));
      await socket.close();

      // 2. HTTP validation
      final response = await http.get(Uri.parse('http://$ip/index')).timeout(const Duration(seconds: 1));
      final body = response.body.toLowerCase();
      
      if (body.contains('obk') || body.contains('openbk')) {
        debugPrint('Device found via Subnet Scan at $ip');
        _addDevice(
          name: 'OBK Plug ($ip)',
          host: ip,
          port: 80,
          ip: ip,
        );
      }
    } catch (_) {
      // Silence expected connection errors
    }
  }

  void _addDevice({required String name, required String host, required int port, required String ip}) {
    if (!_discoveredDevices.any((d) => d.ip == ip)) {
      final device = DiscoveredDevice(
        name: name,
        host: host,
        port: port,
        ip: ip,
      );
      _discoveredDevices.add(device);
      
      // Notify coordinator (SetupService)
      onDeviceDiscovered?.call(device);
      notifyListeners();
    }
  }

  Future<void> _teardownDiscovery() async {
    try {
      await _mdnsDiscovery?.stop();
      _mdnsDiscovery = null;
      _ssdpDiscoverer?.stop();
      _ssdpDiscoverer = null;
      await _multicastLock.releaseMulticastLock();
      debugPrint('Multicast Lock released');
    } catch (e) {
      debugPrint('Error during discovery teardown: $e');
    }
  }

  Future<void> _completeDiscovery() async {
    if (!_isScanning) return;
    await _teardownDiscovery();
    _isScanning = false;
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    await _completeDiscovery();
  }

  @override
  void dispose() {
    stopDiscovery();
    super.dispose();
  }
}
