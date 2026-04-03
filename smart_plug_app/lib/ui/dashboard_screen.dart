import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../core/connection_manager.dart';
import '../core/telemetry_provider.dart';
import 'widgets/power_button.dart';
import 'widgets/telemetry_cards.dart';
import 'insights_tab.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ConnectionMode _previousMode = ConnectionMode.offline;

  @override
  void initState() {
    super.initState();
    final cm = context.read<ConnectionManager>();
    _previousMode = cm.currentMode;
    cm.addListener(_onConnectionChanged);
  }

  void _onConnectionChanged() {
    final cm = context.read<ConnectionManager>();
    if (cm.currentMode != _previousMode) {
      String msg = '';
      if (cm.currentMode == ConnectionMode.local) msg = 'Switched to Local Mode';
      if (cm.currentMode == ConnectionMode.remote) msg = 'Switched to Remote Mode';
      if (cm.currentMode == ConnectionMode.offline) msg = 'Connection Lost';

      if (mounted && msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.grey.shade900,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _previousMode = cm.currentMode;
    }
  }

  @override
  void dispose() {
    // context.read is potentially unsafe here, ignoring for simplicity as it lives at root
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        drawer: const DeviceInfoDrawer(),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'Smart Monitor',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.greenAccent,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
              Tab(icon: Icon(Icons.analytics), text: 'Insights'),
            ],
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF14141c), Color(0xFF000000)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Consumer<TelemetryProvider>(
              builder: (context, provider, child) {
                if (provider.isDisconnected) {
                  return const _DisconnectedShimmer();
                }

                return const TabBarView(
                  children: [
                    _MainDashboardView(),
                    InsightsTab(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _MainDashboardView extends StatelessWidget {
  const _MainDashboardView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          ConnectionStatusHeader(),
          SizedBox(height: 40),
          Center(child: PowerButton()),
          SizedBox(height: 40),
          TelemetryCards(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DisconnectedShimmer extends StatelessWidget {
  const _DisconnectedShimmer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[600]!,
            child: const Icon(
              Icons.sensors_off,
              size: 80,
            ),
          ),
          const SizedBox(height: 20),
          Shimmer.fromColors(
            baseColor: Colors.grey[800]!,
            highlightColor: Colors.grey[600]!,
            child: const Text(
              'Connecting to Device...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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

        switch (manager.currentMode) {
          case ConnectionMode.local:
            statusColor = Colors.greenAccent;
            statusText = 'Local Mode • ${manager.currentSsid ?? "LAN"}';
            break;
          case ConnectionMode.remote:
            statusColor = Colors.blueAccent;
            statusText = 'Cloud Connected';
            break;
          case ConnectionMode.offline:
            statusColor = Colors.redAccent;
            statusText = 'Offline';
            break;
        }

        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }
}

class DeviceInfoDrawer extends StatelessWidget {
  const DeviceInfoDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF14141c),
      child: Consumer<TelemetryProvider>(
        builder: (context, provider, child) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.greenAccent, Colors.blueAccent]),
                ),
                child: Text(
                  'Device Info',
                  style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.memory, color: Colors.white70),
                title: const Text('Firmware Version'),
                subtitle: Text(provider.firmwareVersion, style: const TextStyle(color: Colors.greenAccent)),
              ),
              ListTile(
                leading: const Icon(Icons.wifi, color: Colors.white70),
                title: const Text('IP Address'),
                subtitle: Text(provider.ipAddress, style: const TextStyle(color: Colors.greenAccent)),
              ),
              ListTile(
                leading: const Icon(Icons.barcode_reader, color: Colors.white70),
                title: const Text('MAC Address'),
                subtitle: Text(provider.macAddress, style: const TextStyle(color: Colors.greenAccent)),
              ),
            ],
          );
        },
      ),
    );
  }
}
