import asyncio
import websockets
import random
import json

# Function to randomly choose a horizontal and vertical direction
def generate_random_direction():
    horizontal_directions = ["left", "right", ""]
    vertical_directions = ["up", "down", ""]
    horizontal = random.choice(horizontal_directions)
    vertical = random.choice(vertical_directions)
    return horizontal, vertical

# WebSocket server handler
async def handler(websocket, path):
    client_info = websocket.remote_address
    print(f"Client connected: {client_info[0]}:{client_info[1]}")

    try:
        while True:
            # Generate a random horizontal and vertical direction
            horizontal, vertical = generate_random_direction()

            # Create a dictionary with both horizontal and vertical commands
            data = {
                "horizontal": horizontal,
                "vertical": vertical
            }
            json_data = json.dumps(data)  # Convert the dictionary to JSON string
            
            print(f"Sending data: {json_data}")
            await websocket.send(json_data)  # Send the JSON data to the WebSocket client
            
            await asyncio.sleep(0.5)  # Slight delay between sending messages

    except websockets.ConnectionClosed:
        print(f"Client disconnected: {client_info[0]}:{client_info[1]}")

# Start WebSocket server
async def main():
    async with websockets.serve(handler, "localhost", 8765):
        print("WebSocket server started on ws://localhost:8765")
        await asyncio.Future()  # Run forever

if __name__ == '__main__':
    asyncio.run(main())
