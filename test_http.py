import requests

# Test HTTP through the tunnel
TUNNEL_URL = "https://enhancements-saver-reaches-witch.trycloudflare.com"

print(f"Testing HTTP connection to {TUNNEL_URL}...")
try:
    response = requests.get(TUNNEL_URL, timeout=10)
    print(f"HTTP Status: {response.status_code}")
    print(f"Response: {response.text[:200]}")
except Exception as e:
    print(f"HTTP connection failed: {e}")
