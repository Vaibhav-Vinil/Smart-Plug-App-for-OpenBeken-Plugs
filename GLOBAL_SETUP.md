# Smart Plug — Run with Ctrl+F5

Open the **BKH** folder as the workspace root in Cursor/VS Code (not only `smart_plug_app`).

## Start everything

1. Connect your Android phone (USB debugging) or start an emulator.
2. Choose launch config **Smart Plug App (Phone + Backend)** (or **Emulator + Backend**).
3. Press **F5** (debug) or **Ctrl+F5** (run without debugging).

Each **Ctrl+F5** first stops any old `cloudflared`, `mosquitto`, and `mqtt_recorder` processes, then starts fresh backend terminals and launches the Flutter app:

| Terminal | Service |
|----------|---------|
| Mosquitto Broker | MQTT on `1883`, WebSockets on `9001` |
| Cloudflare Tunnel | Public `wss://…trycloudflare.com/mqtt` bridge |
| MQTT Recorder | History DB (`mqtt_recorder.py`) |

Backend-only (no app): **Terminal → Run Task → Start Global Backend**.

## Backend config file

Edit `backend.config.json` if paths or topic change:

```json
{
  "mqttTopicPrefix": "dubai-plug-test-123",
  "mqttBroker": "localhost",
  "mosquittoExe": "C:\\Program Files\\mosquitto\\mosquitto.exe",
  "mosquittoConfig": "local.conf",
  "cloudflaredExe": "C:\\tools\\cloudflared.exe"
}
```

`mqttTopicPrefix` must match the plug’s **Client Topic** in `http://<plug-ip>/cfg_mqtt`.

## What to enter in the app (Connection settings)

Set these once (or after reinstall). Open the dashboard menu → **Connection settings**.

| Field | Example / notes |
|-------|------------------|
| **Plug IP** | `192.168.1.154` — from plug web UI or router DHCP |
| **MQTT topic prefix** | `dubai-plug-test-123` — same as plug **Client Topic** |
| **Local MQTT broker** | `192.168.1.101` — your PC’s LAN IP (where Mosquitto runs) |
| **MQTT broker port** | `1883` |
| **MQTT username** | `plug_one` — same as on plug (optional if broker is anonymous) |
| **MQTT password** | Same as on plug |
| **Global bridge URL** | `wss://<host>.trycloudflare.com/mqtt` — see below |

Leave **custom publish/subscribe topics** empty unless you use overrides.

### Global bridge URL (required for Global mode)

1. After **Ctrl+F5**, open the **Cloudflare Tunnel** terminal.
2. Find the line like `https://something.trycloudflare.com`.
3. In the app, set **Global bridge URL** to:

   `wss://something.trycloudflare.com/mqtt`

   Use **`wss://`** and the **`/mqtt`** suffix. Copy carefully (**adaptor** vs **adapter** matters).

4. The same URL is saved to `tunnel.url` in the project root when the tunnel starts.

**Every Ctrl+F5** creates a **new** tunnel hostname — copy the new URL from the Cloudflare terminal or `tunnel.url` into the app (old URLs stop working).

### Plug MQTT (web UI)

At `http://<plug-ip>/cfg_mqtt`:

| Setting | Value |
|---------|--------|
| Host | Your PC LAN IP (e.g. `192.168.1.101`) |
| Port | `1883` |
| Client Topic | `dubai-plug-test-123` |
| User / Password | Same as in the app |

## Modes

| Mode | What you need |
|------|----------------|
| **Local** | Plug IP, phone on same Wi‑Fi as plug |
| **Global** | All app fields above + backend running + correct **Global bridge URL** + Global toggle ON |

## Manual commands (if you prefer terminals)

```powershell
cd C:\Users\Vaibhav\Desktop\BKH
& "C:\Program Files\mosquitto\mosquitto.exe" -c "C:\Users\Vaibhav\Desktop\BKH\local.conf" -v
```

```powershell
C:\tools\cloudflared.exe tunnel --url http://localhost:9001
```

```powershell
cd C:\Users\Vaibhav\Desktop\BKH
$env:MQTT_TOPIC_PREFIX="dubai-plug-test-123"
$env:MQTT_BROKER="localhost"
python mqtt_recorder.py
```

```powershell
cd C:\Users\Vaibhav\Desktop\BKH\smart_plug_app
flutter run
```
