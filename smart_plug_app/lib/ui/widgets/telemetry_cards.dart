import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/telemetry_provider.dart';
import 'glass_card.dart';

class TelemetryCards extends StatefulWidget {
  const TelemetryCards({super.key});

  @override
  State<TelemetryCards> createState() => _TelemetryCardsState();
}

class _TelemetryCardsState extends State<TelemetryCards> {
  double _pricePerUnit = 8.0; // Default ₹8.0 per kWh

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pricePerUnit = prefs.getDouble('price_per_unit') ?? 8.0;
    });
  }

  Future<void> _updatePrice(double newPrice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('price_per_unit', newPrice);
    setState(() {
      _pricePerUnit = newPrice;
    });
  }

  void _showPriceDialog() {
    TextEditingController controller = TextEditingController(text: _pricePerUnit.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Set Price per Unit (₹)', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Enter price",
              hintStyle: TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                double? val = double.tryParse(controller.text);
                if (val != null) {
                  _updatePrice(val);
                }
                Navigator.pop(context);
              },
              child: const Text('SAVE', style: TextStyle(color: Colors.greenAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, child) {
        final data = provider.data;
        
        final voltageFormat = NumberFormat('#,##0.0', 'en_US');
        final currentFormat = NumberFormat('#,##0.000', 'en_US');
        final powerFormat = NumberFormat('#,##0', 'en_US');
        final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

        final estimatedBill = data.energyTotal * _pricePerUnit;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildGlassMetric('Voltage', voltageFormat.format(data.voltage), 'V', Icons.electric_bolt, Colors.amber),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGlassMetric('Current', currentFormat.format(data.current), 'A', Icons.waves, Colors.blueAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildGlassMetric('Power', powerFormat.format(data.power), 'W', Icons.flash_on, Colors.orangeAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildGlassMetric('Chip Temp', voltageFormat.format(data.chipTemp), '°C', Icons.thermostat, Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GlassCard(
              onTap: _showPriceDialog,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.greenAccent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Estimated Bill (Total)', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormat.format(estimatedBill),
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, color: Colors.white30, size: 16),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassMetric(String title, String value, String unit, IconData icon, Color iconColor) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
