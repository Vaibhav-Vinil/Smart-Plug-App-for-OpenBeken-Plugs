import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/telemetry_provider.dart';

class ScheduleBottomSheet extends StatefulWidget {
  const ScheduleBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ScheduleBottomSheet(),
    );
  }

  @override
  State<ScheduleBottomSheet> createState() => _ScheduleBottomSheetState();
}

class _ScheduleBottomSheetState extends State<ScheduleBottomSheet> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _turnOn = true;
  static String? _statusMessage;

  void _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _setSchedule() {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);
    
    // If time is in the past, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final duration = scheduledDate.difference(now);
    final telemetry = context.read<TelemetryProvider>();
    final actionStr = _turnOn ? 'ON' : 'OFF';

    // Set schedule on the device
    telemetry.setDeviceSchedule(duration.inSeconds, _turnOn);

    setState(() {
      _statusMessage = 'Device scheduled to turn $actionStr at ${_selectedTime.format(context)}';
    });
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_statusMessage!), 
      backgroundColor: const Color(0xFF1565C0),
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Set Schedule', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Action', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Turn ON')),
                    ButtonSegment(value: false, label: Text('Turn OFF')),
                  ],
                  selected: {_turnOn},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() { _turnOn = newSelection.first; });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF1565C0).withValues(alpha: 0.1);
                        }
                        return Colors.transparent;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
                TextButton(
                  onPressed: _selectTime,
                  child: Text(_selectedTime.format(context), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _setSchedule,
                child: const Text('Save Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
