import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/settings_service.dart';

class DeviceSettingsSheet extends StatefulWidget {
  const DeviceSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: DeviceSettingsSheet(),
      ),
    );
  }

  @override
  State<DeviceSettingsSheet> createState() => _DeviceSettingsSheetState();
}

class _DeviceSettingsSheetState extends State<DeviceSettingsSheet> {
  late final TextEditingController _ipController;
  late final TextEditingController _topicController;
  late final TextEditingController _brokerController;
  late final TextEditingController _brokerPortController;
  late final TextEditingController _mqttUserController;
  late final TextEditingController _mqttPassController;
  late final TextEditingController _globalUrlController;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsService>();
    _ipController = TextEditingController(text: s.plugIpAddress);
    _topicController = TextEditingController(text: s.mqttTopicPrefix);
    _brokerController = TextEditingController(text: s.mqttBrokerHost);
    _brokerPortController =
        TextEditingController(text: s.mqttBrokerPort.toString());
    _mqttUserController = TextEditingController(text: s.mqttUsername);
    _mqttPassController = TextEditingController(text: s.mqttPassword);
    _globalUrlController = TextEditingController(text: s.globalBridgeUrl);
  }

  @override
  void dispose() {
    _ipController.dispose();
    _topicController.dispose();
    _brokerController.dispose();
    _brokerPortController.dispose();
    _mqttUserController.dispose();
    _mqttPassController.dispose();
    _globalUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<SettingsService>();
    final port = int.tryParse(_brokerPortController.text.trim());

    await settings.setPlugIpAddress(_ipController.text);
    await settings.setMqttConfig(
      host: _brokerController.text,
      port: port,
      user: _mqttUserController.text,
      pass: _mqttPassController.text,
      topicPrefix: _topicController.text,
      globalBridgeUrl: _globalUrlController.text,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Connection settings',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure how the app reaches your plug. When you move the plug to a new Wi‑Fi network, open Setup and provision it again, then update the plug IP here if needed.',
              style: TextStyle(color: Colors.black54, height: 1.4),
            ),
            const SizedBox(height: 20),
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
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: 'MQTT topic prefix (plug name in broker)',
                border: OutlineInputBorder(),
                helperText: 'Must match the plug\'s MQTT client topic / name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brokerController,
              decoration: const InputDecoration(
                labelText: 'Local MQTT broker host (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brokerPortController,
              decoration: const InputDecoration(
                labelText: 'MQTT broker port',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mqttUserController,
              decoration: const InputDecoration(
                labelText: 'MQTT username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mqttPassController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'MQTT password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _globalUrlController,
              decoration: const InputDecoration(
                labelText: 'Global bridge URL (optional, wss://…/mqtt)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
