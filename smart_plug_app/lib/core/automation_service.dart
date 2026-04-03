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
    if (data.power > maxPower) {
      if (!_safetyTriggered && data.isRelayOn) {
        _triggerSafetyProtocol('OVERLOAD DETECTED - SHUTTING DOWN');
      }
    }
  }

  void _triggerSafetyProtocol(String message) async {
    _safetyTriggered = true;
    _alertMessage = message;
    notifyListeners();

    debugPrint('SAFETY TRIGGERED: $message');
    // Force off immediately on overload condition.
    if (telemetryProvider.data.isRelayOn) {
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
