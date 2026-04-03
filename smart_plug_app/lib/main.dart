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
            seedColor: const Color(0xFF1565C0), 
            brightness: Brightness.light,
          ).copyWith(
            surface: const Color(0xFFFFFFFF),
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F7FB),
          textTheme: GoogleFonts.interTextTheme(
            Theme.of(context).textTheme.apply(bodyColor: Colors.black87, displayColor: Colors.black87),
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
  Widget build(BuildContext context) {
    return Consumer<AutomationService>(
      builder: (context, automation, child) {
        return Material(
          color: const Color(0xFFF4F7FB),
          child: Column(
            children: [
              if (automation.isSafetyTriggered && automation.alertMessage != null)
                Container(
                  width: double.infinity,
                  color: Colors.redAccent,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 16,
                    bottom: 16,
                    left: 24,
                    right: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          automation.alertMessage!,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => automation.resetSafety(),
                      ),
                    ],
                  ),
                ),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}
