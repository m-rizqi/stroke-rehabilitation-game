extends CharacterBody2D

var websocket_url = "ws://localhost:8765"
@onready var _client : WebSocketClient = $"../WebSocketClient"

var dust: ColorRect
var shader: ShaderMaterial
var hand_pos_list = []  # List to hold dictionaries with position and radius for each "erase" circle
var max_shader_circles = 2000  # Maximum number of circles the shader can handle at once

var direction_input = Vector2.ZERO  # Store the current input direction
var websocket_active = false  # Track if WebSocket input is active

var cleaned_area_percentage = 0.0  # Track the cleaned percentage
var elapsed_minutes: int = 0  # Store elapsed minutes for label update
var elapsed_seconds: int = 0  # Store elapsed seconds for label update

@onready var analysist_label: Label = $"../AnalysistLabel"  # Path to your label
@onready var start_button: Button = $"../ButtonStart"
@onready var reset_button: Button = $"../ButtonReset"

var start_time: int  # Store the start time for tracking elapsed time
var grid_cell_size: float  # Define cell size globally to avoid recalculating it every time
var cleaned_cells = {}  # Dictionary to track unique cleaned cells

var base_radius = 20.0  # Base radius for each force level increment
var horizontal_speed = 0  # Horizontal speed from WebSocket
var vertical_speed = 0    # Vertical speed from WebSocket
var force_level = 0       # Current force level from WebSocket
var should_erase_dust = false  # Flag to trigger dust erasing when force_level > 1

var game_running = false  # Track if the game is running
var game_paused = false  # Track if the game is paused

func _connect_to_websocket():
	print("Attempt to connect websocket %s" % [websocket_url])
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
	var json = JSON.new()
	var error_code = json.parse(message)
	if error_code == OK:
		var msg_dict = json.get_data()
		if msg_dict.has("horizontal") or msg_dict.has("vertical"):
			direction_input = Vector2.ZERO
			if msg_dict["horizontal"] == "right":
				direction_input.x = 1
			elif msg_dict["horizontal"] == "left":
				direction_input.x = -1
			horizontal_speed = msg_dict.get("horizontal_speed", 0)
			if msg_dict["vertical"] == "up":
				direction_input.y = -1
			elif msg_dict["vertical"] == "down":
				direction_input.y = 1
			vertical_speed = msg_dict.get("vertical_speed", 0)
		if msg_dict.has("force_level"):
			force_level = msg_dict["force_level"]
			should_erase_dust = force_level >= 1
		websocket_active = true
	else:
		print("Failed to parse JSON message, error code: %s" % error_code)
		websocket_active = false

func _ready() -> void:
	start_time = Time.get_ticks_msec()  # Record the start time
	_connect_to_websocket()
	
	# Get the Dust node
	dust = get_node("../Dust") as ColorRect
	if dust and dust.material is ShaderMaterial:
		shader = dust.material as ShaderMaterial
		#shader.render_priority = 1  # Ensure it draws above other items if needed
		grid_cell_size = base_radius
	else:
		print("Error: Dust node or ShaderMaterial not found!")
		grid_cell_size = 10.0

	# Connect button signals with Callable syntax
	start_button.connect("pressed", Callable(self, "_on_start_button_pressed"))
	reset_button.connect("pressed", Callable(self, "_on_reset_button_pressed"))
	
	# Initialize button states
	start_button.text = "Start"
	reset_button.disabled = true

	# Disable focus on the Start button to prevent triggering by space or enter
	start_button.focus_mode = Control.FOCUS_NONE


func _on_start_button_pressed() -> void:
	if not game_running:
		game_running = true
		game_paused = false
		start_time = Time.get_ticks_msec()  # Reset the start time
		start_button.text = "Pause"
		reset_button.disabled = false  # Enable the reset button
	elif not game_paused:
		game_paused = true
		start_button.text = "Resume"
	else:
		game_paused = false
		start_button.text = "Pause"

func _on_reset_button_pressed() -> void:
	game_running = false
	game_paused = false
	cleaned_area_percentage = 0.0
	elapsed_minutes = 0
	elapsed_seconds = 0
	cleaned_cells.clear()
	hand_pos_list.clear()
	start_button.text = "Start"
	reset_button.disabled = true
	update_label()  # Update the label to show reset state

# Track movement and erase dust
func _physics_process(delta: float) -> void:
	if game_running and not game_paused:
		update_elapsed_time()
		var manual_input = Vector2.ZERO
		var manual_horizontal_speed = horizontal_speed
		var manual_vertical_speed = vertical_speed

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

		if manual_input != Vector2.ZERO:
			direction_input = manual_input
			direction_input.x *= abs(manual_horizontal_speed)
			direction_input.y *= abs(manual_vertical_speed)
		else:
			direction_input.x *= abs(horizontal_speed)
			direction_input.y *= abs(vertical_speed)

		var new_position = global_position + (direction_input.normalized() * 125 * delta)
		var viewport_size = get_viewport().get_size()
		var sprite = $Sprite2D  # Adjust this path to your actual sprite node
		var texture_width = sprite.texture.get_size().x
		var texture_height = sprite.texture.get_size().y
		new_position.x = clamp(new_position.x, texture_width / 2, viewport_size.x - (texture_width / 2))
		new_position.y = clamp(new_position.y, texture_height / 2, viewport_size.y - (texture_height / 2))
		global_position = new_position

		if should_erase_dust or Input.is_action_pressed("ui_accept"):
			if(Input.is_action_pressed("ui_accept")):
				force_level = 1
			erase_dust()
			update_coverage()

# Only mark new cells cleaned based on erased positions
func erase_dust() -> void:
	var current_radius = force_level * base_radius
	hand_pos_list.append({"position": global_position, "radius": current_radius})
	var grid_x = int(global_position.x / grid_cell_size)
	var grid_y = int(global_position.y / grid_cell_size)
	var cell_pos = Vector2(grid_x, grid_y)
	if not cleaned_cells.has(cell_pos):
		cleaned_cells[cell_pos] = true
	if hand_pos_list.size() > max_shader_circles:
		hand_pos_list = hand_pos_list.slice(hand_pos_list.size() - max_shader_circles, max_shader_circles)
	update_shader()

func update_shader() -> void:
	var positions = []
	var radii = []
	for circle in hand_pos_list:
		positions.append(circle["position"])
		radii.append(circle["radius"])
	shader.set_shader_parameter("hand_pos_list", positions)
	shader.set_shader_parameter("radius_list", radii)
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
	analysist_label.text = "Cleaned: %.2f%%\nTime Elapsed: %d:%02d" % [cleaned_area_percentage, elapsed_minutes, elapsed_seconds]

# Update the full label display with both time and coverage
func update_label() -> void:
	analysist_label.text = "Cleaned: %.2f%%\nTime Elapsed: %d:%02d" % [cleaned_area_percentage, elapsed_minutes, elapsed_seconds]
