import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/connection_manager.dart';
import 'core/telemetry_provider.dart';
import 'core/automation_service.dart';
import 'ui/dashboard_screen.dart';

void main() {
  runApp(const SmartPlugApp());
}

class SmartPlugApp extends StatelessWidget {
  const SmartPlugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionManager()),
        ChangeNotifierProxyProvider<ConnectionManager, TelemetryProvider>(
          create: (context) => TelemetryProvider(context.read<ConnectionManager>()),
          update: (context, connectionManager, telemetryProvider) => 
            telemetryProvider ?? TelemetryProvider(connectionManager),
        ),
        ChangeNotifierProxyProvider<TelemetryProvider, AutomationService>(
          create: (context) => AutomationService(context.read<TelemetryProvider>()),
          update: (context, telemetry, automation) => 
            automation ?? AutomationService(telemetry),
        ),
      ],
      child: MaterialApp(
        title: 'Smart Plug Monitor',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.greenAccent, 
            brightness: Brightness.dark,
          ),
          textTheme: GoogleFonts.interTextTheme(
            Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
          ),
          useMaterial3: true,
        ),
        home: const SafetyWrapper(child: DashboardScreen()),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

// Wrapper to show safety snackbars globally
class SafetyWrapper extends StatefulWidget {
  final Widget child;
  const SafetyWrapper({super.key, required this.child});

  @override
  State<SafetyWrapper> createState() => _SafetyWrapperState();
}

class _SafetyWrapperState extends State<SafetyWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AutomationService>().addListener(_onSafetyAlert);
    });
  }

  void _onSafetyAlert() {
    final automation = context.read<AutomationService>();
    if (automation.isSafetyTriggered && automation.alertMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            automation.alertMessage!,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.yellow,
            onPressed: () {
              automation.resetSafety();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
