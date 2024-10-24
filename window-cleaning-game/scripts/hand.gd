extends CharacterBody2D

var websocket_url = "ws://localhost:8765"
@onready var _client : WebSocketClient = $"../WebSocketClient"

var dust: ColorRect
var shader: ShaderMaterial
var hand_pos_list = []  # List to hold the positions where the hand "erased" the dust
var max_shader_circles = 5000  # Maximum number of circles the shader can handle at once

var direction_input = Vector2.ZERO  # Store the current input direction
var websocket_active = false  # Track if WebSocket input is active

func _connect_to_websocket():
	print("Attempt to connect websocket %s" %[websocket_url])
	var error = _client.connect_to_url(websocket_url)
		
	if error != OK:
		print("Error connecting to websocket: %s" % [websocket_url])

func _on_websocket_client_connection_close():
	var ws = _client.get_socket()
	print("Client disconnected with code: %s, reason: %s" % [ws.get_close_code(), ws.get_close_reason()])
	websocket_active = false  # WebSocket is no longer active

func _on_websocket_client_connected_to_server():
	print("Client connected...")
	websocket_active = true  # WebSocket is now active

# Handle messages from WebSocket server
func _on_websocket_message_received(message):
	print("Message received: %s" % message)

	# Create an instance of the JSON class
	var json = JSON.new()

	# Parse the message
	var error_code = json.parse(message)

	# Check if parsing was successful
	if error_code == OK:
		# Access the parsed result
		var msg_dict = json.get_data()

		# Update direction based on the parsed message
		if msg_dict.has("horizontal") or msg_dict.has("vertical"):
			# Reset the direction input
			direction_input = Vector2.ZERO

			# Handle horizontal direction
			if msg_dict["horizontal"] == "right":
				direction_input.x = 1
			elif msg_dict["horizontal"] == "left":
				direction_input.x = -1

			# Handle vertical direction
			if msg_dict["vertical"] == "up":
				direction_input.y = -1
			elif msg_dict["vertical"] == "down":
				direction_input.y = 1

		websocket_active = true  # WebSocket input is active
	else:
		print("Failed to parse JSON message, error code: %s" % error_code)
		websocket_active = false  # Fall back to manual input if parsing fails


func _ready() -> void:
	_connect_to_websocket()
	 
	# Get the Dust node
	dust = get_node("../Dust") as ColorRect

	# Ensure the dust node exists before accessing its material
	if dust:
		shader = dust.material as ShaderMaterial
	else:
		print("Dust node not found!")

func _physics_process(delta: float) -> void:
	# If WebSocket is inactive, fall back to manual input
	if !websocket_active:
		direction_input = Vector2.ZERO  # Reset direction

		# Handle manual input for movement
		if Input.is_action_pressed("ui_right"):
			direction_input.x = 1
		elif Input.is_action_pressed("ui_left"):
			direction_input.x = -1

		if Input.is_action_pressed("ui_up"):
			direction_input.y = -1
		elif Input.is_action_pressed("ui_down"):
			direction_input.y = 1

	# Use direction_input to move the character
	velocity = direction_input.normalized() * 200  # Adjust speed as necessary
	move_and_slide()

	# If space is pressed, "erase" dust
	if Input.is_action_pressed("ui_accept"):  # Space key mapped as 'ui_accept'
		erase_dust()

func erase_dust() -> void:
	# Add the current hand position to the list
	hand_pos_list.append(global_position)

	# If the list size exceeds max_shader_circles, truncate the oldest positions (this prevents overflow)
	if hand_pos_list.size() > max_shader_circles:
		hand_pos_list = hand_pos_list.slice(hand_pos_list.size() - max_shader_circles, max_shader_circles)

	# Pass the positions to the shader
	update_shader()

func update_shader() -> void:
	# Pass only up to the max_shader_circles to the shader
	var count = min(hand_pos_list.size(), max_shader_circles)
	var hand_keys_list = []
	for i in range(count):
		hand_keys_list.append(i)

	# Pass arrays to the shader
	shader.set_shader_parameter("hand_pos_list", hand_pos_list)
	shader.set_shader_parameter("hand_keys_list", hand_keys_list)
	shader.set_shader_parameter("circle_count", count)
