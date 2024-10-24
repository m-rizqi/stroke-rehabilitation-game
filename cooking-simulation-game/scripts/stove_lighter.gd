extends Node2D

var is_hand_near = false
var interaction_timer = 0.0
var interaction_duration = 3.0  # Hold space for 3 seconds
var is_stove_on = false

@onready var prompt_label = $"../PromptLabel"
@onready var interaction_area = $Area2D
@onready var stove_sprite = $Sprite2D
@onready var outline_circle_sprite = $OutlineCircleSprite

func _ready():
	# Check if prompt_label is valid (not null)
	if prompt_label == null:
		print("Error: PromptLabel node not found.")
	else:
		print("PromptLabel node found.")
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Enable automatic text wrapping
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER  # Align text to center
	# Set a minimum size for the label to ensure it's large enough for wrapping
	prompt_label.custom_minimum_size = Vector2(300, 100)  # Set minimum size for the label to ensure space for wrapping
	# Use Callable to connect signals
	interaction_area.body_entered.connect(Callable(self, "_on_hand_entered"))
	interaction_area.body_exited.connect(Callable(self, "_on_hand_exited"))
	
	# Safely set visibility after checking if prompt_label is valid
	if prompt_label != null:
		prompt_label.visible = false  # Hide the prompt initially

func _on_hand_entered(body):
	if body.name == "CharacterBody2D":  # Detect if the hand entered
		is_hand_near = true
		if prompt_label != null:
			prompt_label.visible = true  # Show the interaction prompt
		outline_circle_sprite.visible = true  # Show the circular sprite outline

func _on_hand_exited(body):
	if body.name == "CharacterBody2D":  # Detect if the hand left
		is_hand_near = false
		if prompt_label != null:
			prompt_label.visible = false  # Hide the prompt
		interaction_timer = 0.0  # Reset the timer
		outline_circle_sprite.visible = false  # Hide the circular sprite outline

func _process(delta):
	if is_hand_near and not is_stove_on:
		# Check if the player is holding the space key
		if Input.is_action_pressed("ui_select"):
			interaction_timer += delta
			# Update the prompt label to show how much time is left
			if prompt_label != null:
				prompt_label.text = "Hold space to light: " + str(int(interaction_duration - interaction_timer))

			# When the timer reaches the interaction duration, rotate the stove lighter
			if interaction_timer >= interaction_duration:
				_turn_on_stove()
		else:
			# If the player releases the space key, reset the timer
			interaction_timer = 0.0
			if prompt_label != null:
				prompt_label.text = "Press space to light the stove"
	else:
		# Hide prompt if not interacting
		if prompt_label != null:
			prompt_label.visible = false

func _turn_on_stove():
	is_stove_on = true
	interaction_timer = 0.0
	if prompt_label != null:
		prompt_label.visible = false
	# Rotate the lighter 90 degrees
	stove_sprite.rotation_degrees = deg_to_rad(90)
	# You can also trigger other things here like playing a sound, turning on a flame, etc.
