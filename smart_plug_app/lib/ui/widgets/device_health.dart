import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/telemetry_provider.dart';

class DeviceHealthSection extends StatelessWidget {
  const DeviceHealthSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, child) {
        return ExpansionTile(
          title: const Text('Device Health', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
          iconColor: const Color(0xFF1565C0),
          collapsedIconColor: Colors.black54,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          childrenPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chip Temp', style: TextStyle(color: Colors.black54)),
                Text('${provider.data.chipTemp}°C', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('WiFi RSSI', style: TextStyle(color: Colors.black54)),
                Text('${provider.data.rssi} dBm', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Firmware', style: TextStyle(color: Colors.black54)),
                Text(provider.firmwareVersion, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('IP Address', style: TextStyle(color: Colors.black54)),
                Text(provider.ipAddress, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ],
        );
      },
    );
  }
}
