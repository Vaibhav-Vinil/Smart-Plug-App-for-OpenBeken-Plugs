import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/telemetry_provider.dart';
import 'smart_tile.dart';

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
        final whFormat = NumberFormat('#,##0.00', 'en_US'); // Wh with two decimals
        final kwhFormat = NumberFormat('#,##0.000', 'en_US'); // kWh with three decimals



        return Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildGridTile('Voltage', voltageFormat.format(data.voltage), 'V', Icons.electric_bolt, Colors.orange),
                _buildGridTile('Current', currentFormat.format(data.current), 'A', Icons.speed, Colors.blue),
                _buildGridTile('Power', powerFormat.format(data.power), 'W', Icons.settings_input_component, Colors.red),
                _buildGridTile('Today', whFormat.format(provider.energyTodayComputed), 'Wh', Icons.today, Colors.teal),
              ],
            ),
            const SizedBox(height: 16.0),
            _buildHorizontalTile(
              'History - Total Energy',
              kwhFormat.format(data.energyTotal / 1000),
              'kWh',
              Icons.history,
              Colors.green,
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridTile(String title, String value, String unit, IconData icon, Color iconColor) {
    return SmartTile(
      padding: const EdgeInsets.all(22.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: iconColor, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      value,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: const TextStyle(color: Colors.black87, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: const TextStyle(color: Colors.black45, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalTile(String title, String value, String unit, IconData icon, Color iconColor) {
    return SmartTile(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(color: Colors.black87, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
