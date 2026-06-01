/// Extracts per-device settings from OpenBeken / Tasmota-style status JSON.
class DeviceConfigParser {
  static String? mqttTopicPrefixFromStatus(Map<String, dynamic> status) {
    final mqt = status['StatusMQT'];
    if (mqt is Map<String, dynamic>) {
      final topic = mqt['Topic'] ?? mqt['topic'];
      if (topic != null && topic.toString().trim().isNotEmpty) {
        return topic.toString().trim();
      }
    }
    return null;
  }

  /// Derive a topic prefix from discovery name (e.g. mDNS service name).
  static String? mqttTopicPrefixFromDeviceName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    // "OBK Plug (192.168.1.5)" -> skip generic scan labels
    if (trimmed.toLowerCase().startsWith('obk plug (')) return null;

    final sanitized = trimmed
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return sanitized.isEmpty ? null : sanitized;
  }
}
