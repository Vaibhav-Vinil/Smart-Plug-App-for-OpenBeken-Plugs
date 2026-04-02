import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/connection_manager.dart';
import 'core/telemetry_provider.dart';
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
      ],
      child: MaterialApp(
        title: 'Smart Plug Monitor',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueAccent, 
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const DashboardScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
