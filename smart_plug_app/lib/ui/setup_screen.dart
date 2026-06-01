import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/settings_service.dart';
import '../core/discovery_service.dart';
import '../core/api_service.dart';
import '../core/device_config_parser.dart';
import '../services/setup_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 2 Form
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // Steps 4–5
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _mqttTopicController = TextEditingController();
  final TextEditingController _mqttBrokerController = TextEditingController();
  final TextEditingController _mqttUserController = TextEditingController();
  final TextEditingController _mqttPassController = TextEditingController();
  final TextEditingController _globalBridgeController = TextEditingController();

  bool _isTestingConnection = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    // Start listening to setup status for auto-navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SetupService>().addListener(_onSetupStatusChanged);
    });
  }

  void _onSetupStatusChanged() {
    final setup = context.read<SetupService>();
    if (setup.status == SetupStatus.discovered) {
      // Magic Jump to Dashboard
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  void dispose() {
    // Avoid memory leaks by removing the listener before disposing the state
    // Note: Since SetupService is shared, we should be careful. 
    // ProxyProvider might recreate it, but the instance in main.dart persists.
    try {
      context.read<SetupService>().removeListener(_onSetupStatusChanged);
    } catch (_) {}
    
    _pageController.dispose();
    _ssidController.dispose();
    _passController.dispose();
    _ipController.dispose();
    _mqttTopicController.dispose();
    _mqttBrokerController.dispose();
    _mqttUserController.dispose();
    _mqttPassController.dispose();
    _globalBridgeController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep++;
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _provision() async {
    final setupService = context.read<SetupService>();
    final success = await setupService.provisionDevice(_ssidController.text, _passController.text);
    
    if (success) {
      // SetupService handles the 10s delay and starting discovery
      // We can transition to the discovery page (Step 3)
      _nextStep();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(setupService.statusMessage ?? 'Failed to reach device. Are you connected to the plug AP?'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testConnection(String ip) async {
    setState(() {
      _isTestingConnection = true;
      _testResult = null;
    });

    final trimmedIp = ip.trim();
    final apiService = ApiService(ip: trimmedIp);
    final status = await apiService.fetchStatus();

    setState(() {
      _isTestingConnection = false;
      if (status != null) {
        _testResult = 'Success! Device reached.';
        _ipController.text = trimmedIp;
        final fromStatus = DeviceConfigParser.mqttTopicPrefixFromStatus(status);
        if (fromStatus != null) {
          _mqttTopicController.text = fromStatus;
        }
      } else {
        _testResult = 'Failed to reach device at $trimmedIp';
      }
    });
  }

  void _selectDiscoveredDevice(DiscoveredDevice device) {
    _ipController.text = device.ip;
    final prefix = DeviceConfigParser.mqttTopicPrefixFromDeviceName(device.name);
    if (prefix != null) {
      _mqttTopicController.text = prefix;
    }
    _pageController.animateToPage(
      4,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = 4);
  }

  Future<void> _finishSetup() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the plug IP address before finishing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final settings = context.read<SettingsService>();
    await settings.saveDeviceSettings(
      ip: ip,
      mqttTopicPrefix: _mqttTopicController.text.trim().isNotEmpty
          ? _mqttTopicController.text.trim()
          : null,
      mqttHost: _mqttBrokerController.text.trim().isNotEmpty
          ? _mqttBrokerController.text.trim()
          : null,
      mqttUser: _mqttUserController.text.trim().isNotEmpty
          ? _mqttUserController.text.trim()
          : null,
      mqttPass: _mqttPassController.text.trim().isNotEmpty
          ? _mqttPassController.text.trim()
          : null,
      globalBridgeUrl: _globalBridgeController.text.trim().isNotEmpty
          ? _globalBridgeController.text.trim()
          : null,
    );

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _step1(),
                        _step2(),
                        _step3(),
                        _step4(),
                        _step5(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.bolt, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            'Device Setup',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${_currentStep + 1} of 5',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30, left: 40, right: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _prevStep,
              child: const Text('Back', style: TextStyle(color: Colors.white, fontSize: 18)),
            )
          else
            const SizedBox(width: 60),
          
          if (_currentStep < 4)
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('Next', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // --- STEPS ---

  Widget _step1() {
    return _buildStepContent(
      title: 'Power On',
      icon: Icons.power_settings_new_rounded,
      content: 'Plug in your Smart Plug. Ensure the LED is blinking fast, indicating it is in AP (Setup) Mode.\n\nThen, connect your phone to the WiFi network named "OpenBK..." or similar.',
      child: Column(
        children: [
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              context.read<SetupService>().startManualDiscovery();
              _pageController.animateToPage(2, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
              setState(() {
                _currentStep = 2; // Jump to Step 3 (index 2)
              });
            },
            icon: const Icon(Icons.flash_on, color: Color(0xFF1565C0)),
            label: const Text(
              'Already on WiFi? Scan now',
              style: TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _step2() {
    return Consumer<SetupService>(
      builder: (context, setup, child) {
        return _buildStepContent(
          title: 'WiFi Connection',
          icon: Icons.wifi_rounded,
          content: 'Enter your Home WiFi details. We will send these to the plug so it can join your network.',
          child: Column(
            children: [
              TextField(
                controller: _ssidController,
                decoration: const InputDecoration(labelText: 'Home WiFi SSID', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'WiFi Password', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              if (setup.statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    setup.statusMessage!,
                    style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: setup.status == SetupStatus.provisioning ? null : _provision,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  child: setup.status == SetupStatus.provisioning 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Provision Device'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _step3() {
    return Consumer2<DiscoveryService, SetupService>(
      builder: (context, discovery, setup, child) {
        String statusText = setup.statusMessage ?? (discovery.isScanning ? 'Searching for your plug...' : 'Ready to scan');
        if (discovery.errorMessage != null) {
          statusText = discovery.errorMessage!;
        }
        
        // Show countdown in Phase 2
        if (setup.status == SetupStatus.waitingToReconnect) {
          statusText = '${setup.statusMessage} (${setup.countdown}s)';
        }

        return _buildStepContent(
          title: 'Network Scan',
          icon: Icons.radar_rounded,
          content: statusText,
          child: Column(
            children: [
              if (setup.status == SetupStatus.waitingToReconnect)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                )
              else ...[
                if (discovery.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              discovery.errorMessage!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: discovery.isScanning
                        ? null
                        : () => discovery.startDiscovery(),
                    icon: Icon(
                      discovery.discoveredDevices.isEmpty
                          ? Icons.search
                          : Icons.refresh,
                    ),
                    label: Text(
                      discovery.isScanning
                          ? 'Scanning...'
                          : (discovery.discoveredDevices.isEmpty
                              ? 'Start Scan'
                              : 'Scan Again'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                if (discovery.isScanning) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: discovery.scanProgress > 0 ? discovery.scanProgress : null,
                          backgroundColor: Colors.blue.shade50,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1565C0)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(discovery.scanProgress * 100).toInt()}% scanned',
                          style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ] else
                  Container(height: 4, color: Colors.transparent),
              ],
              
              const SizedBox(height: 12),
              
              if (discovery.discoveredDevices.isEmpty && setup.status != SetupStatus.waitingToReconnect)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('No devices found yet. Ensure the plug has joined your WiFi.', textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      // Hidden Fallback
                      TextButton(
                        onPressed: () => _pageController.animateToPage(3, duration: const Duration(milliseconds: 400), curve: Curves.easeIn),
                        child: const Text('Still can\'t find your device?', style: TextStyle(color: Color(0xFF1565C0), fontSize: 14)),
                      ),
                    ],
                  ),
                )
              else ...[
                ...discovery.discoveredDevices.map((device) => ListTile(
                  leading: const Icon(Icons.device_hub, color: Color(0xFF1565C0)),
                  title: Text(device.name),
                  subtitle: Text(device.ip),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _selectDiscoveredDevice(device),
                )),
                if (!discovery.isScanning) ...[
                  const SizedBox(height: 8),
                  Text(
                    discovery.discoveredDevices.length == 1
                        ? '1 device found. Tap to select, or scan again.'
                        : '${discovery.discoveredDevices.length} devices found. Tap to select, or scan again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.black45),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _step4() {
    return _buildStepContent(
      title: 'Manual Entry',
      icon: Icons.edit_location_alt_rounded,
      content: 'If discovery failed, enter the IP address of your plug manually.',
      child: Column(
        children: [
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(labelText: 'Device IP address', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isTestingConnection ? null : () => _testConnection(_ipController.text),
              child: _isTestingConnection 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator())
                : const Text('Test Connection'),
            ),
          ),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_testResult!, style: TextStyle(color: _testResult!.contains('Success') ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _step5() {
    return _buildStepContent(
      title: 'All Set!',
      icon: Icons.check_circle_rounded,
      content:
          'Confirm the plug IP. Optional fields are only needed for MQTT remote/global control.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'Plug IP address',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mqttTopicController,
            decoration: const InputDecoration(
              labelText: 'MQTT topic prefix (from plug settings)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mqttBrokerController,
            decoration: const InputDecoration(
              labelText: 'Local MQTT broker host (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mqttUserController,
            decoration: const InputDecoration(
              labelText: 'MQTT username (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mqttPassController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'MQTT password (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _globalBridgeController,
            decoration: const InputDecoration(
              labelText: 'Global bridge URL (optional, wss://…/mqtt)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _finishSetup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text('FINISH', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent({required String title, required IconData icon, required String content, Widget? child}) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Icon(icon, size: 80, color: const Color(0xFF1565C0)),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF1565C0)),
            ),
            const SizedBox(height: 16),
            Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
            ),
            if (child != null) ...[
              const SizedBox(height: 30),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
