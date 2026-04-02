import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/connection_manager.dart';
import 'widgets/power_button.dart';
import 'widgets/telemetry_cards.dart';
import 'widgets/energy_chart.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Plug Monitor'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ConnectionStatusHeader(),
              const SizedBox(height: 24),
              const Center(child: PowerButton()),
              const SizedBox(height: 32),
              const TelemetryCards(),
              const SizedBox(height: 32),
              const EnergyChart(),
            ],
          ),
        ),
      ),
    );
  }
}

class ConnectionStatusHeader extends StatelessWidget {
  const ConnectionStatusHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionManager>(
      builder: (context, manager, child) {
        Color statusColor;
        String statusText;
        IconData statusIcon;

        switch (manager.currentMode) {
          case ConnectionMode.local:
            statusColor = Colors.green;
            statusText = 'Local Mode (${manager.currentSsid ?? "Unknown"})';
            statusIcon = Icons.home;
            break;
          case ConnectionMode.remote:
            statusColor = Colors.blue;
            statusText = 'Remote Mode (Cloud)';
            statusIcon = Icons.cloud;
            break;
          case ConnectionMode.offline:
            statusColor = Colors.red;
            statusText = 'Offline';
            statusIcon = Icons.cloud_off;
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
