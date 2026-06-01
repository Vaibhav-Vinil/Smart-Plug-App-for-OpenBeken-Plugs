import paho.mqtt.client as mqtt
import time

# Cloudflare tunnel URL
TUNNEL_HOST = "donation-width-antiques-res.trycloudflare.com"
TUNNEL_PORT = 443
TOPIC_PREFIX = "plug"
COMMAND_TOPIC = f"{TOPIC_PREFIX}/1/set"

def on_connect(*args):
    client = args[0]
    print(f"Connected successfully")
    # Toggle the plug (send '1' for ON, '0' for OFF)
    print(f"Publishing to {COMMAND_TOPIC}")
    client.publish(COMMAND_TOPIC, "1")
    print("Sent ON command")
    time.sleep(2)
    client.publish(COMMAND_TOPIC, "0")
    print("Sent OFF command")
    time.sleep(1)
    client.disconnect()

def on_disconnect(*args):
    print(f"Disconnected")

client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2, client_id="test_tunnel_client")
client.on_connect = on_connect
client.on_disconnect = on_disconnect

# Configure WebSocket
client.ws_set_options(path="/mqtt")
client.tls_set()

print(f"Connecting to {TUNNEL_HOST}:{TUNNEL_PORT} via WebSocket...")
try:
    client.connect(TUNNEL_HOST, TUNNEL_PORT, 60)
    client.loop_forever()
except Exception as e:
    print(f"Connection failed: {e}")
