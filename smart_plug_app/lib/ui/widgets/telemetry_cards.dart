import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/telemetry_provider.dart';

class TelemetryCards extends StatelessWidget {
  const TelemetryCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, child) {
        final data = provider.data;
        
        final voltageFormat = NumberFormat('#,##0.0', 'en_US');
        final currentFormat = NumberFormat('#,##0.000', 'en_US');
        final powerFormat = NumberFormat('#,##0', 'en_US');

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildCard('Voltage', '${voltageFormat.format(data.voltage)} V', Icons.electric_bolt, Colors.amber),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCard('Current', '${currentFormat.format(data.current)} A', Icons.waves, Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildCard('Power', '${powerFormat.format(data.power)} W', Icons.flash_on, Colors.orange),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildCard('Chip Temp', '${voltageFormat.format(data.chipTemp)} °C', Icons.thermostat, Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                 Expanded(
                  child: _buildCard('WiFi RSSI', '${data.rssi} dBm', Icons.wifi, Colors.greenAccent),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
