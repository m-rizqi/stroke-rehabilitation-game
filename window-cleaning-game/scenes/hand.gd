extends CharacterBody2D

var dust: ColorRect
var shader: ShaderMaterial

var hand_pos_dict = {}  # Dictionary to hold the positions where the hand "erased" the dust
var circle_count = 0    # Counter for how many erasers/circles are added
var max_circles = 1000  # Initial maximum number of circles (matches shader)

func _ready() -> void:
	# Get the Dust node
	dust = get_node("../Dust") as ColorRect

	# Ensure the dust node exists before accessing its material
	if dust:
		shader = dust.material as ShaderMaterial
	else:
		print("Dust node not found!")

func _physics_process(delta: float) -> void:
	var vel := Vector2.ZERO

	# Arrow key input for controlling the hand
	if Input.is_action_pressed("ui_right"):
		vel.x += 1
	if Input.is_action_pressed("ui_left"):
		vel.x -= 1
	if Input.is_action_pressed("ui_down"):
		vel.y += 1
	if Input.is_action_pressed("ui_up"):
		vel.y -= 1

	# Normalize and multiply velocity to set the hand speed
	velocity = vel.normalized() * 200  # Adjust the speed as necessary
	move_and_slide()

	# If space is pressed, "erase" dust
	if Input.is_action_pressed("ui_accept"):  # Space key mapped as 'ui_accept'
		erase_dust()

func erase_dust() -> void:
	# Resize hand_pos_dict dynamically if needed
	resize_hand_dict()

	# Add the current hand position to the dictionary with an index key
	hand_pos_dict[circle_count] = global_position
	circle_count += 1  # Increase the count of circles

	# Prepare dictionary data for the shader (only the first `max_circles` entries)
	var hand_pos_list = []
	var hand_keys_list = []
	
	for i in range(min(circle_count, max_circles)):
		hand_pos_list.append(hand_pos_dict[i])
		hand_keys_list.append(i)  # Keys are just the indices

	# Pass arrays to the shader
	shader.set_shader_parameter("hand_pos_list", hand_pos_list)
	shader.set_shader_parameter("hand_keys_list", hand_keys_list)
	shader.set_shader_parameter("circle_count", min(circle_count, max_circles))

func resize_hand_dict() -> void:
	# If the dictionary has reached the current maximum size
	if circle_count >= max_circles:
		max_circles *= 2  # Double the maximum size
		print("Resized hand_pos_dict to new max:", max_circles)
