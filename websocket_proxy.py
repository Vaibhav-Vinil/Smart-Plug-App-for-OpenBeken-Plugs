import asyncio
import websockets
from websockets.server import WebSocketServerProtocol

async def proxy_handler(websocket):
    """Proxy WebSocket connections to Mosquitto"""
    path = websocket.request.path
    print(f"Proxy: New connection from {websocket.remote_address}, path: {path}")
    
    # Only handle /mqtt path
    if path != "/mqtt":
        print(f"Proxy: Rejecting connection - wrong path: {path}")
        await websocket.close()
        return
    
    try:
        # Connect to Mosquitto WebSocket
        mosquitto_uri = "ws://localhost:9001/mqtt"
        print(f"Proxy: Connecting to Mosquitto at {mosquitto_uri}")
        async with websockets.connect(mosquitto_uri, subprotocols=["mqtt"]) as mosquitto_ws:
            print(f"Proxy: Connected to Mosquitto for client {websocket.remote_address}")
            
            # Bidirectional proxy
            async def forward_to_mosquitto():
                try:
                    async for message in websocket:
                        print(f"Proxy: Client -> Mosquitto: {len(message)} bytes")
                        await mosquitto_ws.send(message)
                except websockets.exceptions.ConnectionClosed as e:
                    print(f"Proxy: Client connection closed: {e}")
            
            async def forward_to_client():
                try:
                    async for message in mosquitto_ws:
                        print(f"Proxy: Mosquitto -> Client: {len(message)} bytes")
                        await websocket.send(message)
                except websockets.exceptions.ConnectionClosed as e:
                    print(f"Proxy: Mosquitto connection closed: {e}")
            
            # Run both directions concurrently
            await asyncio.gather(forward_to_mosquitto(), forward_to_client())
            
    except Exception as e:
        print(f"Proxy error: {e}")
    finally:
        print(f"Proxy: Client {websocket.remote_address} disconnected")

async def main():
    print("Starting WebSocket proxy on port 8082...")
    print("Proxying /mqtt to ws://localhost:9001/mqtt")
    
    async with websockets.serve(proxy_handler, "localhost", 8082):
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())
