Run these in terminals
C:\Users\Vaibhav> mosquitto -c local.conf -v
PS C:\Users\Vaibhav> cloudflared tunnel --url http://localhost:9001
PS C:\Users\Vaibhav\Desktop\BKH\smart_plug_app> flutter run
Make change to line 244

Access the plug here locally
http://192.168.1.106/index

# smart_plug_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


To Run the App on windows
flutter emulators --launch Medium_Phone_API_36.1
flutter run -d emulator-5554

To run on Andoid Phone
cd c:/Users/Vaibhav/Desktop/BKH/smart_plug_app
flutter run

http://192.168.1.106/index

---

## Global Mode Architecture (Cloudflare + MQTT)

The application supports a "Global Bridge" feature allowing secure, remote access to your smart plugs from outside your local network. It achieves this by tunneling an MQTT WebSocket connection through a Cloudflare Zero Trust Tunnel directly to your local Mosquitto broker.

If you are shifting this architecture to a new MQTT broker or a new Cloudflare account, follow this checklist to ensure all the components correctly align.

### 1. The Smart Plug (Hardware Side)
The smart plugs (running OpenBeken or Tasmota) are hardcoded to communicate with a specific broker.
- **MQTT Host:** Change the host in the plug's Web UI to match your new Cloudflare URL (e.g., `new-broker-link.trycloudflare.com`).
- **MQTT Topic:** If the new plug has a different "Name", the base topic (e.g., `dubai-plug-test-123`) must be updated in the plug's settings.
- **Credentials:** If the new MQTT broker has a different username/password, update them in the plug's Web UI.

### 2. Cloudflare Tunnel (The "Bridge")
If you move to a new Cloudflare account, the current "Tunnel" will stop working.
- **New Tunnel Token:** You’ll need to create a new tunnel in the Cloudflare Zero Trust dashboard and obtain a new Tunnel Token.
- **Public Hostname:** Re-map the new tunnel to point to your local Mosquitto broker’s IP and WebSocket port (e.g., `http://192.168.x.x:9001`).
- **The URL:** Cloudflare will generate a new URL (or you can use a custom domain).

### 3. The Flutter Project (Software Side)
Update the Flutter codebase to point to your new infrastructure:
- **Broker URL:** In `lib/core/telemetry_provider.dart` (or your config file), update the connection URL.
  > **Crucial Requirement:** Always keep the `wss://` prefix and the `/mqtt` suffix intact (e.g., `wss://new-url.trycloudflare.com/mqtt`). Do NOT set `client.secure = true` when using `wss://` with `mqtt_client`.
- **Base Topic:** Update `activePublishTopic` and `activeSubscribeTopic` in `TelemetryProvider` so the app knows where to send the `1`/`0` payload. 
- **Client IDs:** The app dynamically generates a unique Client ID (appending a timestamp) to prevent the "fighting loop" disconnect issue on the broker.
- **Credentials:** Update the auth logic if the new broker uses different credentials.

### 4. The MQTT Broker (The "Server")
If you are migrating Mosquitto to a different PC or Raspberry Pi:
- **mosquitto.conf:** Ensure the new setup explicitly allows WebSockets. You must configure a separate listener (e.g., `listener 9001 0.0.0.0` and `protocol websockets`).
- **IP Address:** Update the Cloudflare Tunnel configuration so it routes incoming web traffic to the new local IP of this Mosquitto machine.