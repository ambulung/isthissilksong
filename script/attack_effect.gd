extends Area2D

# Signal emitted when this attack effect successfully hits an enemy.
# It passes the enemy Node that was hit.
signal hit_enemy(enemy_node: Node)

# Reference to the actual visual Sprite2D (or AnimatedSprite2D) child node.
# IMPORTANT: Make sure "$Sprite2D" matches the exact name of your visual sprite node
# within the AttackEffect.tscn scene. If you renamed it (e.g., to "Visual"),
# change this path to "$Visual".
@onready var visual_sprite: Sprite2D = $Sprite2D

# Reference to the Timer node that controls how long this attack effect lasts.
@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready():
	# Connect the lifetime timer's timeout signal. When the timer runs out,
	# this AttackEffect node will be removed from the scene tree.
	lifetime_timer.timeout.connect(queue_free)
	
	# Connect the Area2D's body_entered signal. This signal is emitted when
	# a physics body (like CharacterBody2D, RigidBody2D, etc.) enters this Area2D's collision shape.
	body_entered.connect(_on_body_entered)

	# --- Debugging (Optional, remove after testing) ---
	# print("AttackEffect spawned. Visual sprite path: ", visual_sprite.get_path() if visual_sprite else "NOT FOUND")

func _on_body_entered(body: Node):
	# Check if the collided body belongs to the "enemy" group.
	# Ensure your enemy nodes are added to the "enemy" group in their Node -> Groups tab.
	if body.is_in_group("enemy"):
		# Emit the signal, passing the enemy node that was hit.
		# The player script will listen to this signal to deal damage and potentially bounce.
		emit_signal("hit_enemy", body)
		
		# Immediately remove the attack effect from the scene after it hits something.
		# This prevents it from hitting multiple times or lingering unnecessarily.
		queue_free()

# This function is called by the Player script to set the visual direction of the attack.
# direction_x will be 1.0 for right, -1.0 for left.
func set_attack_direction(direction_x: float):
	# Only attempt to flip if the visual_sprite node was successfully found.
	if visual_sprite:
		visual_sprite.flip_h = direction_x < 0
		# --- Debugging (Optional, remove after testing) ---
		# print("AttackEffect: set_attack_direction called. visual_sprite.flip_h set to: ", visual_sprite.flip_h)
	else:
		# If visual_sprite is null, it means the path in @onready var visual_sprite is incorrect.
		push_error("AttackEffect: visual_sprite node was not found! Cannot flip.")
