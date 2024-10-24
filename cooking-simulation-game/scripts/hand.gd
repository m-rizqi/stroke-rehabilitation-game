extends CharacterBody2D

@export var speed: float = 300.0  # Speed at which the hand moves

func _ready():
	# Set the hand's initial position to the center of the screen
	position = get_viewport_rect().size / 2
	# Set a high z_index to ensure the hand is rendered on top
	z_index = 10  # You can choose a high value like 10 or higher

func _physics_process(delta: float) -> void:
	var velocity = Vector2.ZERO  # Initialize velocity as zero

	# Detect input for movement (arrow keys)
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1
	if Input.is_action_pressed("ui_left"):
		velocity.x -= 1
	if Input.is_action_pressed("ui_up"):
		velocity.y -= 1
	if Input.is_action_pressed("ui_down"):
		velocity.y += 1

	# Normalize velocity to ensure consistent movement in diagonal directions
	if velocity != Vector2.ZERO:
		velocity = velocity.normalized() * speed

	# Move the hand based on the velocity and delta time
	velocity *= delta
	position += velocity

	# Keep the hand within the screen bounds
	_clamp_to_screen()

func _clamp_to_screen() -> void:
	# Get the screen size (viewport size)
	var screen_size = get_viewport_rect().size

	# Clamp the position so the hand stays inside the screen
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
