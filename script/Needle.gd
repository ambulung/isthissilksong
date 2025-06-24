extends Area2D

signal stuck(attach_position)

@export var speed: float = 800.0
# The 'grapple_damage' export has been removed.

var direction: Vector2 = Vector2.RIGHT
var travel_distance: float = 0.0
var max_distance: float = 600.0
var is_stuck: bool = false

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if is_stuck:
		return

	var distance_to_move = speed * delta
	global_position += direction * distance_to_move
	travel_distance += distance_to_move

	if travel_distance >= max_distance:
		queue_free()

func launch(start_pos: Vector2, launch_direction: Vector2, max_range: float):
	global_position = start_pos
	direction = launch_direction.normalized()
	max_distance = max_range
	rotation = direction.angle()

func _on_body_entered(body: Node):
	if is_stuck or body.is_in_group("player"):
		return
		
	# If it's an enemy, it "sticks" for a moment to start the grapple, then disappears.
	if body.is_in_group("enemy"):
		# The damage logic has been removed.
		stuck.emit(body.global_position) 
		queue_free()
		return
	
	# If we hit a wall, we stick permanently.
	is_stuck = true
	stuck.emit(global_position)
	set_physics_process(false)
