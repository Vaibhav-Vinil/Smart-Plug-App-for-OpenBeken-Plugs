import sqlite3
import paho.mqtt.client as mqtt
import json
import time
import os

# --- CONFIGURATION (environment-driven, no hardcoded deployment values) ---
MQTT_BROKER = os.environ.get("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.environ.get("MQTT_PORT", "1883"))
MQTT_TOPIC_PREFIX = os.environ.get("MQTT_TOPIC_PREFIX", "plug").strip()
DB_FILE = os.environ.get("DB_FILE", "smart_plug_history.db")

if not MQTT_TOPIC_PREFIX:
    raise SystemExit(
        "Set MQTT_TOPIC_PREFIX to your plug's MQTT client topic/name "
        "(same value as in the Flutter app Connection settings)."
    )

TOPIC_SUB = f"{MQTT_TOPIC_PREFIX}/#"
TOPIC_REQ = f"{MQTT_TOPIC_PREFIX}/history/req"
TOPIC_RES = f"{MQTT_TOPIC_PREFIX}/history/res"

# --- DATABASE SETUP ---
def init_db():
    conn = sqlite3.connect(DB_FILE)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS history 
                 (timestamp REAL, topic TEXT, payload TEXT)''')
    conn.commit()
    conn.close()

def log_to_db(topic, payload):
    if "/history/" in topic: return # Don't log history requests
    try:
        conn = sqlite3.connect(DB_FILE)
        c = conn.cursor()
        c.execute("INSERT INTO history VALUES (?, ?, ?)", (time.time(), topic, payload))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"DB Log Error: {e}")

def get_history(range_str="1h"):
    try:
        conn = sqlite3.connect(DB_FILE)
        c = conn.cursor()
        
        # Calculate start time
        now = time.time()
        if range_str == "5m":
            since = now - 300
            interval = 0
        elif range_str == "1h":
            since = now - 3600
            interval = 0 # No aggregation
        elif range_str == "24h":
            since = now - 86400
            interval = 300 # 5 minute average
        elif range_str == "7d":
            since = now - (7 * 86400)
            interval = 3600 # 1 hour average
        else:
            since = now - 3600
            interval = 0

        c.execute("SELECT timestamp, payload FROM history WHERE topic LIKE '%power%' AND topic NOT LIKE '%power_factor%' AND timestamp > ? ORDER BY timestamp ASC", (since,))
        rows = c.fetchall()
        conn.close()

        if not rows: return []

        if interval == 0:
            return [[round(r[0], 1), float(r[1])] for r in rows]
        
        # Simple bucket aggregation
        buckets = {}
        for r in rows:
            bucket_ts = (r[0] // interval) * interval
            if bucket_ts not in buckets: buckets[bucket_ts] = []
            buckets[bucket_ts].append(float(r[1]))
        
        aggregated = []
        for ts in sorted(buckets.keys()):
            avg = sum(buckets[ts]) / len(buckets[ts])
            aggregated.append([round(ts, 1), round(avg, 2)])
        
        return aggregated
    except Exception as e:
        print(f"DB Fetch Error: {e}")
        return []

# --- MQTT HANDLERS ---
def on_connect(client, userdata, flags, rc, properties=None):
    print(f"Connected to Mosquitto (code {rc})")
    client.subscribe(TOPIC_SUB)

def on_message(client, userdata, msg):
    topic = msg.topic
    try:
        payload = msg.payload.decode()
    except:
        return

    if topic == TOPIC_REQ:
        print(f"History requested: {payload}")
        range_val = "1h"
        try:
            req_data = json.loads(payload)
            range_val = req_data.get("range", "1h")
        except:
            pass
            
        history_data = get_history(range_val)
        client.publish(TOPIC_RES, json.dumps(history_data))
        print(f"Sent {len(history_data)} points for range {range_val} to {TOPIC_RES}")
    else:
        # Log telemetry data
        if any(key in topic for key in ['voltage', 'current', 'power', 'energycounter']):
            # Ensure it's a valid number before logging
            try:
                float(payload)
                log_to_db(topic, payload)
            except:
                pass

# --- MAIN ---
print("--- Smart Plug History Recorder ---")
print(f"Broker: {MQTT_BROKER}:{MQTT_PORT}")
print(f"Topic prefix: {MQTT_TOPIC_PREFIX}")
init_db()
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION2)
client.on_connect = on_connect
client.on_message = on_message

print(f"Connecting to {MQTT_BROKER}:{MQTT_PORT}...")
try:
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    print(f"Monitoring {TOPIC_SUB}...")
    client.loop_forever()
except Exception as e:
    print(f"Could not connect to MQTT: {e}")
    print("Is Mosquitto running?")
