# Needle.gd
extends Area2D

# Signal to notify the player when the needle has stuck to a surface.
signal stuck(attach_position)

var speed: float = 800.0
var direction: Vector2 = Vector2.RIGHT
var travel_distance: float = 0.0
var max_distance: float = 600.0
var is_stuck: bool = false

func _ready():
	# This connects the signal that fires when our Area2D's mask
	# overlaps with a PhysicsBody's layer.
	# Without the correct Layer/Mask setup, this signal will never fire.
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if is_stuck:
		return

	# Move the needle forward
	var distance_to_move = speed * delta
	global_position += direction * distance_to_move
	travel_distance += distance_to_move

	# If the needle travels too far, destroy it.
	if travel_distance >= max_distance:
		queue_free()

# This function is called from the Player to initialize the needle.
func launch(start_pos: Vector2, launch_direction: Vector2, max_range: float):
	global_position = start_pos
	direction = launch_direction.normalized()
	max_distance = max_range
	# Rotate the needle sprite to face the direction of travel.
	rotation = direction.angle()

# This function is now guaranteed to fire when hitting a wall,
# because we set up the layers and masks correctly.
func _on_body_entered(body: Node):
	# Don't do anything if we are already stuck or if we somehow hit the player.
	if is_stuck or body.is_in_group("player"):
		return
		
	# As requested, if it's an enemy, it doesn't stick. The needle just disappears.
	# The enemy should be in the "enemy" group for this to work.
	if body.is_in_group("enemy"):
		queue_free()
		return
	
	# If we hit any other valid physics body (like our "world" TileMap), we stick!
	is_stuck = true
	# Emit the signal to the player, sending our exact impact position.
	stuck.emit(global_position)
	# Stop the needle from moving any further.
	set_physics_process(false)
