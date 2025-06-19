extends Camera2D

# We use @onready to ensure the node is available when the scene is loaded.
# We find the player by looking for the first node in the "player" group.
# Make sure your Player node is added to the "player" group!
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")

func _ready():
	if player == null:
		push_warning("Player node not found in 'player' group for Camera2D to follow!")
		# If player not found, disable the script to prevent errors
		set_process(false) 
		set_physics_process(false)

func _physics_process(delta: float):
	# We use _physics_process to match the player's movement,
	# preventing potential jitters if player moves in _physics_process
	# and camera moves in _process.

	if player:
		# Simply set the camera's global position to the player's global position.
		# The Camera2D's built-in smoothing and limits handle the rest.
		global_position = player.global_position
