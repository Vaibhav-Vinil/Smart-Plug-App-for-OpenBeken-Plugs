import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiService {
  final String _baseUrl = 'http://${SecretConfig.plugIpAddress}:${SecretConfig.localHttpPort}';

  Future<Map<String, dynamic>?> fetchStatus() async {
    try {
      final response8 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%208'));
      debugPrint('RAW STATUS 8: ${response8.body}');
      
      final response11 = await http.get(Uri.parse('$_baseUrl/cm?cmnd=status%2011'));
      
      if (response8.statusCode == 200 && response11.statusCode == 200) {
        try {
          Map<String, dynamic> data8 = json.decode(utf8.decode(response8.bodyBytes));
          
          // Fallback if status 8 doesn't have the expected nested status
          if (!data8.containsKey('StatusSNS') && !data8.containsKey('Status')) {
            final fallback = await http.get(Uri.parse('$_baseUrl/cm?cmnd=EnergyStatus'));
            debugPrint('RAW FALLBACK (EnergyStatus): ${fallback.body}');
            if (fallback.statusCode == 200) {
              final fbData = json.decode(utf8.decode(fallback.bodyBytes));
              data8['EnergyStatus'] = fbData;
            }
          }
          
          final data11 = json.decode(utf8.decode(response11.bodyBytes));
          return {
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
    try {
      final response = await http.get(Uri.parse('$_baseUrl/cm?cmnd=Power%20Toggle'));
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
