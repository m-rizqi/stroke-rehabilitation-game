import asyncio
import websockets
import serial
import json

# Configure your serial port and baud rate
SERIAL_PORT = "COM9"  # Change to your ESP32 port (e.g., "COM3" on Windows or "/dev/ttyUSB0" on Linux)
BAUD_RATE = 115200

# Initialize the serial connection
ser = serial.Serial(SERIAL_PORT, BAUD_RATE)
ser.flushInput()  # Clear initial buffer to ignore any previous data

# Threshold for speed increase
SPEED_DELTA_THRESHOLD = 45
FORCE_DELTA_THRESHOLD =500

# Previous roll and pitch values and speed variables
previous_roll = 0
previous_pitch = 0
roll_speed = 0
pitch_speed = 0

# Variable to store the latest direction data
latest_direction_data = {
    "horizontal": "",
    "vertical": "",
    "horizontal_speed": 0,
    "vertical_speed": 0,
    "fsr": 0,
    "force_level": 0
}

# WebSocket server handler
async def handler(websocket, path):
    global previous_roll, previous_pitch, roll_speed, pitch_speed, latest_direction_data

    client_info = websocket.remote_address
    print(f"Client connected: {client_info[0]}:{client_info[1]}")

    async def send_latest_data():
        while True:
            # Send the latest direction data every 1 second
            json_data = json.dumps(latest_direction_data)
            print(f"Sending data: {json_data}")
            await websocket.send(json_data)
            await asyncio.sleep(1)  # Send every 1 second

    # Start the task to send data every second
    asyncio.create_task(send_latest_data())

    try:
        while True:
            # Read the latest data from the serial buffer
            if ser.in_waiting > 0:
                serial_data = ser.readline().decode("utf-8").strip()
                print("Serial data: ", serial_data)
                
                # Parse the JSON data from the serial input
                try:
                    data = json.loads(serial_data)
                    roll = data.get("roll", 0)
                    pitch = data.get("pitch", 0)
                    fsr = data.get("fsr", 0)  # Get fsr value
                    
                    # Determine horizontal and vertical directions based on roll and pitch values
                    horizontal = "left" if roll < 0 else "right" if roll > 0 else ""
                    vertical = "down" if pitch < 0 else "up" if pitch > 0 else ""
                    
                    # Calculate the delta changes from previous values
                    roll_delta = abs(roll - previous_roll)
                    pitch_delta = abs(pitch - previous_pitch)
                    
                    # Update roll and pitch speed based on the delta threshold
                    if roll_delta >= SPEED_DELTA_THRESHOLD:
                        roll_speed += 1 if roll > previous_roll else -1
                        previous_roll = roll  # Update previous roll to current roll

                    if pitch_delta >= SPEED_DELTA_THRESHOLD:
                        pitch_speed += 1 if pitch > previous_pitch else -1
                        previous_pitch = pitch  # Update previous pitch to current pitch

                    # Calculate force level based on fsr
                    force_level = fsr // FORCE_DELTA_THRESHOLD
                    
                    # Update the latest direction data
                    latest_direction_data = {
                        "horizontal": horizontal,
                        "vertical": vertical,
                        "horizontal_speed": roll_speed,
                        "vertical_speed": pitch_speed,
                        "fsr": fsr,
                        "force_level": force_level
                    }
                    
                except (ValueError, json.JSONDecodeError):
                    print("Invalid JSON format received from serial:", serial_data)

            # Immediate continuation to next serial read
            await asyncio.sleep(0)  # Non-blocking wait for asyncio

    except websockets.ConnectionClosed:
        print(f"Client disconnected: {client_info[0]}:{client_info[1]}")

# Start WebSocket server
async def main():
    async with websockets.serve(handler, "localhost", 8765):
        print("WebSocket server started on ws://localhost:8765")
        await asyncio.Future()  # Run forever

if __name__ == '__main__':
    asyncio.run(main())
