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
import 'widgets/daily_energy_chart.dart';
import 'device_settings_sheet.dart';

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
                onChanged: (val) {
                  final settings = context.read<SettingsService>();
                  if (val && !settings.canUseGlobalMode) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Set MQTT topic prefix and global bridge URL in Connection settings first.',
                        ),
                      ),
                    );
                    return;
                  }
                  settings.setGlobalMode(val);
                },
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
              if (value == 'settings') {
                DeviceSettingsSheet.show(context);
              } else if (value == 'reconfigure') {
                Navigator.of(context).pushNamed('/setup');
              } else if (value == 'delete') {
                _showDeleteConfirmation(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, color: Color(0xFF1565C0)),
                    SizedBox(width: 8),
                    Text('Connection settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reconfigure',
                child: Row(
                  children: [
                    Icon(Icons.wifi, color: Color(0xFF1565C0)),
                    SizedBox(width: 8),
                    Text('Reconfigure Wi‑Fi'),
                  ],
                ),
              ),
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
          if (!provider.hasLiveData && provider.isDisconnected) {
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
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Usage History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['5M', '1H', '24H', '7D'].map((range) {
                            final isSelected = provider.selectedRange == range.toLowerCase();
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ChoiceChip(
                                label: Text(range, style: TextStyle(fontSize: 10, color: isSelected ? Colors.white : Colors.black54)),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    provider.updateHistoryRange(range.toLowerCase());
                                  }
                                },
                                selectedColor: const Color(0xFF1565C0),
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _SmoothLineChart(),
                const SizedBox(height: 16),
                const DailyEnergyChart(),
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
              height: 300,
              child: Center(child: Text('Gathering data...', style: TextStyle(color: Colors.black45))),
            ),
          );
        }

        final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
        double minX;
        if (provider.selectedRange == '5m') {
          minX = now - 300;
        } else if (provider.selectedRange == '1h') {
          minX = now - 3600;
        } else if (provider.selectedRange == '24h') {
          minX = now - 86400;
        } else if (provider.selectedRange == '7d') {
          minX = now - (7 * 86400);
        } else {
          minX = now - 3600;
        }

        List<FlSpot> spots = history.map((e) => FlSpot(e.key, e.value)).toList();
        
        // Sort by X (timestamp) to prevent zig-zagging "back and forth" lines
        spots.sort((a, b) => a.x.compareTo(b.x));
        
        // Only keep spots within the window for the line chart display
        spots = spots.where((s) => s.x >= minX).toList();

        double maxY = 10;
        if (spots.isNotEmpty) {
          maxY = spots.map((s) => s.y).reduce((curr, next) => curr > next ? curr : next) * 1.5;
        }
        if (maxY < 10) maxY = 10;

        // Wider chart for better scrolling: 
        // 5M view = 5 screens wide, 1H view = 3 screens wide, etc.
        double chartWidth;
        if (provider.selectedRange == '5m') {
          chartWidth = (MediaQuery.of(context).size.width - 48) * 5;
        } else if (provider.selectedRange == '1h') {
          chartWidth = (MediaQuery.of(context).size.width - 48) * 3;
        } else if (provider.selectedRange == '24h') {
          chartWidth = (MediaQuery.of(context).size.width - 48) * 6;
        } else {
          chartWidth = (MediaQuery.of(context).size.width - 48) * 12;
        }

        return SmartTile(
          padding: const EdgeInsets.only(top: 32, bottom: 0, left: 0, right: 0),
          child: SizedBox(
            height: 300,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true, // Start at the current time (right side)
              child: Padding(
                padding: const EdgeInsets.only(right: 24, left: 12), // Extra space for labels
                child: SizedBox(
                  width: chartWidth,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        drawHorizontalLine: true,
                        getDrawingHorizontalLine: (val) => FlLine(color: Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
                        getDrawingVerticalLine: (val) => FlLine(color: Colors.black.withValues(alpha: 0.05), strokeWidth: 1),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const Text('');
                              return Text('${value.toInt()}W', style: const TextStyle(color: Colors.black26, fontSize: 10));
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: (now - minX) / 12, // 12 labels across the scrollable area
                            getTitlesWidget: (value, meta) {
                              final date = DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
                              String label;
                              if (provider.selectedRange == '5m') {
                                label = '${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
                              } else if (provider.selectedRange == '1h') {
                                label = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
                              } else if (provider.selectedRange == '24h') {
                                label = '${date.hour}:00';
                              } else {
                                label = '${date.day}/${date.month}';
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(label, style: const TextStyle(color: Colors.black26, fontSize: 10)),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.1), width: 1),
                          left: BorderSide(color: Colors.black.withValues(alpha: 0.1), width: 1),
                        ),
                      ),
                      minX: minX,
                      maxX: now,
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
              ),
            ),
          ),
        );
      },
    );
  }
}
