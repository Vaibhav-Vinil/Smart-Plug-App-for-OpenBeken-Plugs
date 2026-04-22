import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/settings_service.dart';
import '../core/connection_manager.dart';
import '../core/telemetry_provider.dart';
import 'widgets/neumorphic_toggle.dart';
import 'widgets/telemetry_cards.dart';
import 'widgets/schedule_bottom_sheet.dart';
import 'widgets/smart_tile.dart';
import 'widgets/device_health.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device?'),
        content: const Text('This will remove the current smart plug from the app. You will need to set it up again to use it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final settings = context.read<SettingsService>();
              await settings.deleteCurrentDevice();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/setup', (route) => false);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const ConnectionBadge(),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: context.watch<SettingsService>().isGlobalModeEnabled,
                onChanged: (val) => context.read<SettingsService>().setGlobalMode(val),
                activeColor: Colors.purple,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF1565C0)),
            onPressed: () => Navigator.of(context).pushNamed('/setup'),
            tooltip: 'Add Device',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF1565C0)),
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteConfirmation(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Device', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<TelemetryProvider>(
        builder: (context, provider, child) {
          if (provider.isDisconnected && provider.data.power == 0 && provider.data.voltage == 0) {
            return const _LoadingShimmer();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HeroHeader(),
                const SizedBox(height: 32),
                const Center(child: NeumorphicToggle()),
                const SizedBox(height: 32),
                
                // Schedule Trigger
                GestureDetector(
                  onTap: () => ScheduleBottomSheet.show(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.schedule, color: Color(0xFF1565C0), size: 20),
                        SizedBox(width: 8),
                        Text('Set Schedule', style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                
                const TelemetryCards(),
                const SizedBox(height: 32),
                
                const Text(
                  'Usage History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                const _SmoothLineChart(),
                const SizedBox(height: 32),

                const DeviceHealthSection(),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionManager>(
      builder: (context, manager, child) {
        final isLocal = manager.currentMode == ConnectionMode.local;
        final isGlobal = manager.currentMode == ConnectionMode.global;
        
        Color badgeColor;
        IconData badgeIcon;
        String badgeText;
        
        if (isGlobal) {
          badgeColor = Colors.purple;
          badgeIcon = Icons.public;
          badgeText = 'Global Bridge Active';
        } else if (isLocal) {
          badgeColor = Colors.green;
          badgeIcon = Icons.wifi;
          badgeText = 'Local';
        } else {
          badgeColor = Colors.blue;
          badgeIcon = Icons.cloud;
          badgeText = 'Cloud';
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon, size: 14, color: badgeColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  badgeText,
                  style: TextStyle(color: badgeColor, fontWeight: FontWeight.w700, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text('Online', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Smart Plug',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5),
        ),
        const Text(
          'Living Room',
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ],
    );
  }
}

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 4,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmoothLineChart extends StatelessWidget {
  const _SmoothLineChart();

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, child) {
        final history = provider.powerHistory;

        if (history.isEmpty) {
          return const SmartTile(
            child: SizedBox(
              height: 180,
              child: Center(child: Text('Gathering data...', style: TextStyle(color: Colors.black45))),
            ),
          );
        }

        List<FlSpot> spots = [];
        for (int i = 0; i < history.length; i++) {
          spots.add(FlSpot(i.toDouble(), history[i]));
        }

        double maxY = history.reduce((curr, next) => curr > next ? curr : next) * 1.5;
        if (maxY < 10) maxY = 10;

        return SmartTile(
          padding: const EdgeInsets.only(top: 32, bottom: 0, left: 0, right: 0),
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  drawHorizontalLine: true,
                  getDrawingHorizontalLine: (val) => FlLine(color: Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        return Container(); // Keep generic empty ticks
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.1), width: 1)),
                ),
                minX: 0,
                maxX: spots.length.toDouble() > 50 ? spots.length.toDouble() : 50,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF1565C0),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    shadow: Shadow(color: const Color(0xFF1565C0).withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 4)),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF1565C0).withValues(alpha: 0.2),
                          const Color(0xFF1565C0).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
