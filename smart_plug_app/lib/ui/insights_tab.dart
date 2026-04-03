import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/telemetry_provider.dart';
import 'widgets/glass_card.dart';

class InsightsTab extends StatelessWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Live Insights',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const _EnergySummaryList(),
          const SizedBox(height: 32),
          const Text(
            'Power Consumption (Session)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const _PowerLineChart(),
        ],
      ),
    );
  }
}

class _EnergySummaryList extends StatelessWidget {
  const _EnergySummaryList();

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, child) {
        final data = provider.data;
        return Row(
          children: [
            Expanded(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(data.energyToday.toStringAsFixed(3), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                    const Text('kWh', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(data.energyTotal.toStringAsFixed(3), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const Text('kWh', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PowerLineChart extends StatelessWidget {
  const _PowerLineChart();

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, child) {
        final history = provider.powerHistory;
        
        if (history.isEmpty) {
          return const GlassCard(
            child: SizedBox(
              height: 200,
              child: Center(child: Text('Gathering data...', style: TextStyle(color: Colors.grey))),
            ),
          );
        }

        List<FlSpot> spots = [];
        for (int i = 0; i < history.length; i++) {
          spots.add(FlSpot(i.toDouble(), history[i]));
        }

        // Determine dynamic maxY to keep chart looking nice
        double maxY = history.reduce((curr, next) => curr > next ? curr : next) * 1.5;
        if (maxY < 10) maxY = 10; // floor

        return GlassCard(
          padding: const EdgeInsets.only(top: 24, bottom: 12, left: 12, right: 24),
          child: SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: spots.length.toDouble() > 50 ? spots.length.toDouble() : 50,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.greenAccent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.greenAccent.withValues(alpha: 0.15),
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
