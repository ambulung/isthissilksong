# File: camera_controller.gd
extends Camera2D

# --- EXPORTED VARIABLES ---
@export_group("Following")
@export var follow_lerp_speed: float = 7.0 # How quickly the camera follows the player.

@export_group("Look Panning")
@export var look_ahead_vertical: float = 60.0 # How far to pan from the base offset.
@export var pan_lerp_speed: float = 5.0

# Find the player by looking for the first node in the "player" group.
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")

# --- MODIFIED: Variables to store your base offset ---
var _base_offset: Vector2  # This will store the offset from the Inspector.
var _target_offset: Vector2 # This is the offset we will smoothly move towards.

func _ready():
	if player == null:
		push_warning("Player node not found in 'player' group for Camera2D to follow!")
		set_physics_process(false)
		return

	# --- THE CRITICAL FIX ---
	# 1. Capture the initial offset you set in the Inspector.
	_base_offset = self.offset
	# 2. Set our starting target to this base offset.
	_target_offset = _base_offset

	# Set the camera's initial position instantly.
	global_position = player.global_position

	# Connect to the player's signal for look panning.
	if player.has_signal("look_direction_changed"):
		player.look_direction_changed.connect(_on_player_look_direction_changed)
	else:
		push_warning("Camera could not find 'look_direction_changed' signal on player.")


func _physics_process(delta: float):
	if is_instance_valid(player):
		# Smoothly interpolate the camera's position towards the player.
		global_position = global_position.lerp(player.global_position, follow_lerp_speed * delta)
	
	# Smoothly interpolate the camera's offset towards the target offset.
	offset = offset.lerp(_target_offset, pan_lerp_speed * delta)
	
	# Optional: For a perfect pixel-art look.
	# global_position = global_position.round()


# This function handles the signal from the player.
func _on_player_look_direction_changed(y_direction: float):
	# Calculate the temporary pan amount based on player input.
	var pan_amount = y_direction * look_ahead_vertical
	
	# --- MODIFIED LOGIC ---
	# Set the target offset by ADDING the pan amount to your BASE offset.
	_target_offset = _base_offset + Vector2(0, pan_amount)
