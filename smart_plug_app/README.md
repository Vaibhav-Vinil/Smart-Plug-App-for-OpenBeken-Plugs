# Smart Plug App

A Flutter application that monitors and controls smart plugs via MQTT over a Cloudflare tunnel.

## Getting Started

1. **Install dependencies**
```bash
flutter pub get
```
2. **Run the app**
```bash
# Android device
flutter run

# Emulator (replace with your emulator ID)
flutter emulators --launch Medium_Phone_API_36.1
flutter run -d emulator-5554
```

## Architecture Overview

- **MQTT Broker**: Mosquitto with WebSocket listener (port 9001).
- **Cloudflare Tunnel**: Securely expose the broker to the internet (`wss://<your‑tunnel>.trycloudflare.com/mqtt`).
- **Flutter App**: Connects to the broker, publishes/receives telemetry, and displays data.

## Configuration

Update the broker URL in `lib/core/telemetry_provider.dart` if you change the Cloudflare tunnel:
```dart
const String brokerUrl = 'wss://<your‑tunnel>.trycloudflare.com/mqtt';
```

## Cleaned Project Notes

- Removed placeholder test files (`test_client.dart`, `test_ws.dart`).
- Deleted the entire `test/` directory.
- Updated imports and UI widgets to avoid overflow and ensure consistent formatting.
- Simplified the README by removing outdated commands and irrelevant instructions.

## Running on Windows

Ensure you have an Android emulator or a connected device, then execute:
```bash
flutter run
```

---

For more details on the global bridge architecture, see the **Global Mode Architecture** section in the original documentation.