import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../../core/telemetry_provider.dart';

class PowerButton extends StatelessWidget {
  const PowerButton({super.key});

  void _triggerHaptic() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, child) {
        final isOn = provider.data.isRelayOn;
        final isLoading = provider.isLoading;

        return GestureDetector(
          onTap: isLoading ? null : () {
            _triggerHaptic();
            provider.togglePower();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            height: 160,
            width: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black,
              border: Border.all(
                color: isOn ? Colors.greenAccent : Colors.redAccent.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isOn ? Colors.greenAccent.withValues(alpha: 0.6) : Colors.redAccent.withValues(alpha: 0.1),
                  blurRadius: isOn ? 40 : 15,
                  spreadRadius: isOn ? 10 : 2,
                ),
                // Inner glow simulate
                BoxShadow(
                  color: isOn ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.black,
                  blurRadius: 10,
                  spreadRadius: -5,
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Icon(
                      Icons.power_settings_new,
                      size: 70,
                      color: isOn ? Colors.white : Colors.grey.shade800,
                    ),
            ),
          ),
        );
      },
    );
  }
}
