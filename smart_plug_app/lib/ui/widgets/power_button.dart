import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/telemetry_provider.dart';

class PowerButton extends StatelessWidget {
  const PowerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TelemetryProvider>(
      builder: (context, provider, child) {
        final isOn = provider.data.isRelayOn;
        final isLoading = provider.isLoading;

        return GestureDetector(
          onTap: isLoading ? null : () => provider.togglePower(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOn ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
              border: Border.all(
                color: isOn ? Colors.green : Colors.grey,
                width: 4,
              ),
              boxShadow: [
                if (isOn)
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : Icon(
                      Icons.power_settings_new,
                      size: 80,
                      color: isOn ? Colors.green : Colors.grey,
                    ),
            ),
          ),
        );
      },
    );
  }
}
