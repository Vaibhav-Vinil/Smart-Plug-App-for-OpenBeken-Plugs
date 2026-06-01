import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'device_defaults.dart';

class ApiService {
  String _ip;
  final String _port;

  ApiService({required String ip, String port = DeviceDefaults.httpPort})
      : _ip = ip,
        _port = port;

  void updateIp(String newIp) {
    _ip = newIp;
  }

  String get _baseUrl => 'http://$_ip:$_port';

  Future<Map<String, dynamic>?> fetchStatus() async {
    try {
      final response8 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%208')).timeout(const Duration(seconds: 3));
      
      final response11 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%2011')).timeout(const Duration(seconds: 2));
      final response5 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%205')).timeout(const Duration(seconds: 2));
      final response2 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%202')).timeout(const Duration(seconds: 2));
      
      if (response8.statusCode == 200) {
        try {
          Map<String, dynamic> data8 = json.decode(utf8.decode(response8.bodyBytes));
          
          if (!data8.containsKey('StatusSNS') && !data8.containsKey('Status')) {
            final fallback = await http.get(Uri.parse('$_baseUrl/cm?cmnd=EnergyStatus')).timeout(const Duration(seconds: 2));
            if (fallback.statusCode == 200) {
              final fbData = json.decode(utf8.decode(fallback.bodyBytes));
              data8['EnergyStatus'] = fbData;
            }
          }
          
          Map<String, dynamic> data11 = response11.statusCode == 200 ? json.decode(utf8.decode(response11.bodyBytes)) : {};
          Map<String, dynamic> data5 = response5.statusCode == 200 ? json.decode(utf8.decode(response5.bodyBytes)) : {};
          Map<String, dynamic> data2 = response2.statusCode == 200 ? json.decode(utf8.decode(response2.bodyBytes)) : {};
          
          return {
            ...data2,
            ...data5,
            ...data11,
            ...data8,
          };
        } catch (e) {
          debugPrint('JSON Parsing Error: $e');
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('HTTP Fetch Error: $e');
      return null;
    }
  }

  Future<bool> togglePower() async => (await _sendCommand('Power%20Toggle')) != null;
  Future<bool> turnOff() async => (await _sendCommand('Power%20Off')) != null;
  Future<bool> turnOn() async => (await _sendCommand('Power%20On')) != null;

  Future<String?> sendRawCommand(String cmd) async {
    // Ensure the command is URL encoded for the 'cmnd' parameter
    return _sendCommand(Uri.encodeComponent(cmd));
  }

  Future<String?> _sendCommand(String cmd) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/cm?cmnd=$cmd')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.body;
      }
      return null;
    } catch (e) {
      debugPrint('HTTP Command Error: $e');
      return null;
    }
  }

}
