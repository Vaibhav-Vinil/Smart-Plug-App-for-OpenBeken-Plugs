import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import '../../core/telemetry_provider.dart';
import 'smart_tile.dart';

class NeumorphicToggle extends StatefulWidget {
  const NeumorphicToggle({super.key});

  @override
  State<NeumorphicToggle> createState() => _NeumorphicToggleState();
}

class _NeumorphicToggleState extends State<NeumorphicToggle> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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

        if (isOn) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.value = 0.0;
        }

        return SmartTile(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            children: [
              GestureDetector(
                onTap: isLoading ? null : () {
                  _triggerHaptic();
                  provider.togglePower();
                },
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 140,
                      width: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOn ? const Color(0xFFE8F0FE) : const Color(0xFFF0F0F0),
                        border: Border.all(
                          color: isOn ? const Color(0xFF1565C0) : Colors.grey.shade300,
                          width: isOn ? 4 : 2,
                        ),
                        boxShadow: isOn
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1565C0).withValues(alpha: 0.3 * _pulseAnimation.value),
                                  blurRadius: 20 * _pulseAnimation.value,
                                  spreadRadius: 5 * _pulseAnimation.value,
                                )
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                )
                              ],
                      ),
                      child: Center(
                        child: isLoading
                            ? const CircularProgressIndicator(color: Color(0xFF1565C0))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.power_settings_new,
                                    size: 36,
                                    color: isOn ? const Color(0xFF1565C0) : Colors.grey.shade500,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isOn ? 'ON' : 'OFF',
                                    style: TextStyle(
                                      color: isOn ? const Color(0xFF1565C0) : Colors.grey.shade500,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Power Control',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
