extends CharacterBody2D

var dust: ColorRect
var shader: ShaderMaterial

var hand_pos_list = []   # List to hold the positions where the hand "erased" the dust
var circle_count = 0     # Counter for how many erasers/circles are added

func _ready() -> void:
	# Get the Dust node
	dust = get_node("../Dust") as ColorRect
	
	# Ensure the dust node exists before accessing its material
	if dust:
		shader = dust.material as ShaderMaterial
	else:
		print("Dust node not found!")

func _physics_process(delta: float) -> void:
	# Move the hand towards the mouse position
	var vel := (get_global_mouse_position() - global_position) * 100
	velocity = vel
	move_and_slide()

	# If left click or Enter is pressed, "erase" dust
	if Input.is_action_pressed("click"):
		erase_dust()

func erase_dust() -> void:
	# Add the current hand position to the list
	hand_pos_list.append(global_position)
	circle_count += 1  # Increase the count of circles
	
	# Send the updated list and circle count to the shader
	shader.set_shader_parameter("hand_pos_list", hand_pos_list)
	shader.set_shader_parameter("circle_count", circle_count)
