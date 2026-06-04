# Smart Plug App for OpenBeken

An advanced, Flutter-based application designed to monitor and control smart plugs running OpenBeken (or Tasmota) firmware. The app seamlessly transitions between ultra-fast local HTTP control and secure remote MQTT telemetry over a Cloudflare Zero Trust tunnel.

## 🚀 Key Features

*   **Dynamic Network Routing**: Automatically detects your home Wi-Fi SSID to switch between Local Mode (<50ms latency via HTTP REST) and Global Mode (cellular remote access via MQTT WebSockets).
*   **Comprehensive Energy Analytics**: Tracks real-time voltage, current, and power. Accurately distinguishes day-to-day energy spent (Today, Yesterday, 2-Days Ago, 3-Days Ago) natively in Watt-hours (Wh).
*   **Historical Telemetry**: Stores a rolling window of the last 1000 telemetry points locally and syncs with a Python-based SQLite recorder backend for long-term historical charts.
*   **Zero-Config Auto Discovery**: Uses mDNS (Zeroconf), SSDP (UPnP), and aggressive subnet sweeping to find unconfigured plugs on your network without manual IP entry.
*   **Overload Protection**: A background automation service actively monitors live wattage and instantly cuts power if a load exceeds 2500W.
*   **Premium Neumorphic UI**: Features an animated 3D switch, adaptive choice chips, and a highly responsive `fl_chart` interactive telemetry graph.

## 🏗️ Architecture Overview

The ecosystem consists of four main pillars:
1.  **OpenBeken Smart Plug**: The IoT hardware acting as the HTTP server and MQTT client.
2.  **Mosquitto Broker**: The central message bus handling local TCP traffic (1883) and WebSocket traffic (9001).
3.  **Telemetry Recorder (`mqtt_recorder.py`)**: Persists live MQTT telemetry to a local SQLite database (`smart_plug_history.db`).
4.  **Flutter App**: The cross-platform mobile client coordinating the data flow and UI rendering.

## 🛠️ Getting Started

### 1. Backend Setup
*Ensure you have Python and Mosquitto installed.*
1. Start the Mosquitto broker: `mosquitto -c local.conf -v`
2. Expose the broker via Cloudflare: `cloudflared tunnel --url http://localhost:9001`
3. Run the telemetry recorder: `python mqtt_recorder.py`

### 2. App Setup
Ensure you have Flutter installed and an Android emulator or physical device connected.
```bash
# Get dependencies
flutter pub get

# Run the app
flutter run
```

## ⚙️ Configuration

Update the bridge URL in the in-app **Connection Settings** to match your generated Cloudflare tunnel (e.g., `wss://<your-tunnel>.trycloudflare.com/mqtt`).

## 📚 Documentation

For an exhaustive, in-depth exploration of every feature, function, service, and architectural decision within the project, please refer to the **[Documentation.md](../Documentation.md)** and **[GLOBAL_SETUP.md](../GLOBAL_SETUP.md)** files in the root directory.