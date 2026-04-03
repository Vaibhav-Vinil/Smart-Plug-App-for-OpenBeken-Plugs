import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiService {
  final String _baseUrl = 'http://${SecretConfig.plugIpAddress}:${SecretConfig.localHttpPort}';

  Future<Map<String, dynamic>?> fetchStatus() async {
    try {
      final response8 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%208'));
      
      // Secondary queries (we don't strictly require 200 on all for the loop to parse what it gets)
      final response11 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%2011'));
      final response5 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%205'));
      final response2 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%202'));
      
      if (response8.statusCode == 200) {
        try {
          Map<String, dynamic> data8 = json.decode(utf8.decode(response8.bodyBytes));
          
          if (!data8.containsKey('StatusSNS') && !data8.containsKey('Status')) {
            final fallback = await http.get(Uri.parse('$_baseUrl/cm?cmnd=EnergyStatus'));
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
          debugPrint('JSON Parsing Error (ignoring frame): $e');
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint('HTTP Fetch Error: $e');
      return null;
    }
  }

  Future<bool> togglePower() async {
    return _sendCommand('Power%20Toggle');
  }

  Future<bool> turnOff() async {
    return _sendCommand('Power%20Off');
  }

  Future<bool> _sendCommand(String cmd) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/cm?cmnd=$cmd'));
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('HTTP Command Error: $e');
      return false;
    }
  }
}
