import 'package:flutter/foundation.dart';
import 'telemetry_provider.dart';

class AutomationService extends ChangeNotifier {
  final TelemetryProvider telemetryProvider;
  bool _safetyTriggered = false;
  String? _alertMessage;
  
  bool get isSafetyTriggered => _safetyTriggered;
  String? get alertMessage => _alertMessage;

  AutomationService(this.telemetryProvider) {
    telemetryProvider.addListener(_onTelemetryUpdated);
  }

  void _onTelemetryUpdated() {
    final data = telemetryProvider.data;
    
    // Safety thresholds
    const double maxPower = 2500.0;
    const double maxVoltage = 270.0;

    if (data.power > maxPower || data.voltage > maxVoltage) {
      if (!_safetyTriggered && data.isRelayOn) {
        _triggerSafetyProtocol('OVERLOAD DETECTED! Power overrides active.');
      }
    } else {
      // Optional: Auto-recover or leave it manual. We'll leave it manual by requiring the user to dismiss/restart or turn back on explicitly.
    }
  }

  void _triggerSafetyProtocol(String message) async {
    _safetyTriggered = true;
    _alertMessage = message;
    notifyListeners();

    debugPrint('SAFETY TRIGGERED: $message');
    // Force off
    if (telemetryProvider.data.isRelayOn) {
      // Send toggle command (assuming it toggles, but to be completely deterministic we should send OFF, but togglePower is what we have right now). 
      // Tasmota: "Power off" command is better. I will add an explicit off command to api/mqtt later. 
      // For now, if it's ON, togglePower will turn it OFF.
      await telemetryProvider.turnOff(); 
    }
  }

  void resetSafety() {
    _safetyTriggered = false;
    _alertMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    telemetryProvider.removeListener(_onTelemetryUpdated);
    super.dispose();
  }
}
