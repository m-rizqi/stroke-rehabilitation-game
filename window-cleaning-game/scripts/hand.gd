extends CharacterBody2D

var websocket_url = "ws://localhost:8765"
@onready var _client : WebSocketClient = $"../WebSocketClient"

var dust: ColorRect
var shader: ShaderMaterial
var hand_pos_list = []  # List to hold dictionaries with position and radius for each "erase" circle
var max_shader_circles = 5000  # Maximum number of circles the shader can handle at once

var direction_input = Vector2.ZERO  # Store the current input direction
var websocket_active = false  # Track if WebSocket input is active

var cleaned_area_percentage = 0.0  # Track the cleaned percentage
var elapsed_minutes: int = 0  # Store elapsed minutes for label update
var elapsed_seconds: int = 0  # Store elapsed seconds for label update

@onready var analysist_label: Label = $"../AnalysistLabel"  # Path to your label

var start_time: int  # Store the start time for tracking elapsed time
var grid_cell_size: float  # Define cell size globally to avoid recalculating it every time
var cleaned_cells = {}  # Dictionary to track unique cleaned cells

var base_radius = 20.0  # Base radius for each force level increment
var horizontal_speed = 0  # Horizontal speed from WebSocket
var vertical_speed = 0    # Vertical speed from WebSocket
var force_level = 0       # Current force level from WebSocket
var should_erase_dust = false  # Flag to trigger dust erasing when force_level > 1

func _connect_to_websocket():
	print("Attempt to connect websocket %s" %[websocket_url])
	var error = _client.connect_to_url(websocket_url)
		
	if error != OK:
		print("Error connecting to websocket: %s" % [websocket_url])

func _on_websocket_client_connection_close():
	var ws = _client.get_socket()
	
	if ws:  # Check if ws is valid
		print("Client disconnected with code: %s, reason: %s" % [ws.get_close_code(), ws.get_close_reason()])
	else:
		print("Failed to retrieve WebSocket instance.")
	
	websocket_active = false  # Set WebSocket as inactive regardless

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

			# Handle horizontal direction and speed
			if msg_dict["horizontal"] == "right":
				direction_input.x = 1
			elif msg_dict["horizontal"] == "left":
				direction_input.x = -1
			horizontal_speed = msg_dict.get("horizontal_speed", 0)

			# Handle vertical direction and speed
			if msg_dict["vertical"] == "up":
				direction_input.y = -1
			elif msg_dict["vertical"] == "down":
				direction_input.y = 1
			vertical_speed = msg_dict.get("vertical_speed", 0)

		# Update force level and radius
		if msg_dict.has("force_level"):
			force_level = msg_dict["force_level"]
			should_erase_dust = force_level > 1  # Set the flag if force level is more than 1

		websocket_active = true  # WebSocket input is active
	else:
		print("Failed to parse JSON message, error code: %s" % error_code)
		websocket_active = false  # Fall back to manual input if parsing fails

func _ready() -> void:
	start_time = Time.get_ticks_msec()  # Record the start time
	_connect_to_websocket()

	# Get the Dust node
	dust = get_node("../Dust") as ColorRect

	# Ensure the dust node exists before accessing its material
	if dust and dust.material is ShaderMaterial:
		shader = dust.material as ShaderMaterial
		# Set grid cell size to base_radius or a custom default value if needed
		grid_cell_size = base_radius  # Use a default based on base_radius
	else:
		print("Error: Dust node or ShaderMaterial not found!")
		grid_cell_size = 10.0  # Set a default value to avoid further errors

	# Timer to update coverage periodically
	var timer = Timer.new()
	timer.wait_time = 1.0  # Update every 1 second
	timer.one_shot = false
	timer.autostart = true
	timer.connect("timeout", Callable(self, "_on_timer_timeout"))
	add_child(timer)

func _on_timer_timeout() -> void:
	update_coverage()  # Update coverage periodically

# Track movement and erase dust
func _physics_process(delta: float) -> void:
	# Update time display each frame
	update_elapsed_time()

	# Override WebSocket input with manual input if any arrow key is pressed
	var manual_input = Vector2.ZERO
	var manual_horizontal_speed = horizontal_speed
	var manual_vertical_speed = vertical_speed

	# Check for manual input and set speeds to 1 if any arrow key is pressed
	if Input.is_action_pressed("ui_right"):
		manual_input.x = 1
		manual_horizontal_speed = 1
	elif Input.is_action_pressed("ui_left"):
		manual_input.x = -1
		manual_horizontal_speed = 1

	if Input.is_action_pressed("ui_up"):
		manual_input.y = -1
		manual_vertical_speed = 1
	elif Input.is_action_pressed("ui_down"):
		manual_input.y = 1
		manual_vertical_speed = 1

	# Use manual input if present, otherwise fallback to WebSocket input
	if manual_input != Vector2.ZERO:
		direction_input = manual_input
		direction_input.x *= abs(manual_horizontal_speed)
		direction_input.y *= abs(manual_vertical_speed)
	else:
		# Apply the WebSocket direction and speed if no manual input
		direction_input.x *= abs(horizontal_speed)
		direction_input.y *= abs(vertical_speed)

	# Use direction_input to move the character
	velocity = direction_input.normalized() * 125   # Adjust speed as necessary
	move_and_slide()

	# Automatically erase dust if force_level > 1
	if should_erase_dust or Input.is_action_pressed("ui_accept"):
		erase_dust()
		update_coverage()

# Only mark new cells cleaned based on erased positions
func erase_dust() -> void:
	# Calculate the radius for this circle based on force level
	var current_radius = force_level * base_radius

	# Store position and radius as a dictionary in hand_pos_list
	hand_pos_list.append({"position": global_position, "radius": current_radius})

	# Track cleaned cells efficiently
	var grid_x = int(global_position.x / grid_cell_size)
	var grid_y = int(global_position.y / grid_cell_size)
	var cell_pos = Vector2(grid_x, grid_y)

	# Mark this cell as cleaned if not already tracked
	if not cleaned_cells.has(cell_pos):
		cleaned_cells[cell_pos] = true  # Add cell to cleaned cells

	# If list exceeds max shader circles, truncate to prevent overflow
	if hand_pos_list.size() > max_shader_circles:
		hand_pos_list = hand_pos_list.slice(hand_pos_list.size() - max_shader_circles, max_shader_circles)

	update_shader()

func update_shader() -> void:
	# Separate positions and radii to send to the shader
	var positions = []
	var radii = []

	for circle in hand_pos_list:
		positions.append(circle["position"])
		radii.append(circle["radius"])

	# Pass arrays to the shader
	shader.set_shader_parameter("hand_pos_list", positions)
	shader.set_shader_parameter("radius_list", radii)  # This will hold the radius of each circle
	shader.set_shader_parameter("circle_count", min(hand_pos_list.size(), max_shader_circles))

# Calculate coverage based on unique cleaned cells and update the label
func update_coverage() -> void:
	var window_size = dust.get_rect().size
	var total_cells = int((window_size.x / grid_cell_size) * (window_size.y / grid_cell_size))
	cleaned_area_percentage = float(cleaned_cells.size()) / float(total_cells) * 100.0
	cleaned_area_percentage = min(cleaned_area_percentage, 100.0)
	update_label()

# Separate time display update for accurate polling
func update_elapsed_time() -> void:
	var elapsed_msec = Time.get_ticks_msec() - start_time
	elapsed_minutes = int(elapsed_msec / 60000)
	elapsed_seconds = int((elapsed_msec % 60000) / 1000)
	
	# Update only the time portion of the label
	analysist_label.text = "Cleaned: %.2f%%\nTime Elapsed: %d:%02d" % [cleaned_area_percentage, elapsed_minutes, elapsed_seconds]

# Update the full label display with both time and coverage
func update_label() -> void:
	analysist_label.text = "Cleaned: %.2f%%\nTime Elapsed: %d:%02d" % [cleaned_area_percentage, elapsed_minutes, elapsed_seconds]
