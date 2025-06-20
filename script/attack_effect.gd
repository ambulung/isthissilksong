extends Area2D

signal hit_enemy(enemy_node: Node)

@onready var visual_sprite: Sprite2D = $AttackVisual
@onready var lifetime_timer: Timer = $LifetimeTimer

var already_hit = false
var pending_direction_x: float = 1.0  # Default facing right

func _ready():
	lifetime_timer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

	if visual_sprite:
		apply_attack_direction()
	else:
		push_error("❌ visual_sprite is NULL in _ready()")

func _on_body_entered(body: Node):
	if already_hit:
		return
	if body.is_in_group("enemy"):
		already_hit = true
		emit_signal("hit_enemy", body)
		queue_free()

# Called externally by player to tell which direction this attack faces
func set_attack_direction(direction_x: float):
	pending_direction_x = direction_x

	if is_inside_tree() and visual_sprite:
		apply_attack_direction()

# Apply only rotation based on direction (no flipping)
func apply_attack_direction():
	if not visual_sprite:
		push_error("❌ visual_sprite is NULL in apply_attack_direction()")
		return

	if pending_direction_x == 0.0:
		# Down attack
		visual_sprite.rotation_degrees = 90
		print("🔽 Down attack: rotated to 90°")
	elif pending_direction_x > 0.0:
		# Right attack
		visual_sprite.rotation_degrees = 0
		print("➡ Right attack: rotated to 0°")
	else:
		# Left attack
		visual_sprite.rotation_degrees = 180
		print("⬅ Left attack: rotated to 180°")
