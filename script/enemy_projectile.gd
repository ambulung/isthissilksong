# File: enemy_projectile.gd
extends Area2D

@export var speed: float = 200.0
@export var damage: int = 10

# REMOVED: parried_damage, parried_speed_multiplier, is_parried, shooter

var direction: Vector2 = Vector2.RIGHT

func _ready():
	body_entered.connect(_on_body_entered)
	# It can optionally stay in this group if you want to identify it for other reasons later.
	add_to_group("enemy_projectile") 
	
	# The projectile can only hit the player.
	set_collision_mask_value(1, true) # Layer 1 is 'player'
	set_collision_mask_value(3, false) # Layer 3 is 'enemies'

func _physics_process(delta: float):
	position += direction * speed * delta

# SIMPLIFIED: The launch function no longer needs the shooter.
func launch(start_position: Vector2, launch_direction: Vector2):
	global_position = start_position
	direction = launch_direction.normalized()
	rotation = direction.angle()

func _on_body_entered(body: Node):
	# SIMPLIFIED: No need to check if it was parried. It just checks for the player.
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		queue_free() # Destroy itself after hitting the player.

# REMOVED: The entire parry() function is gone.
