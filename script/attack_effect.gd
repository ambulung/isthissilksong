# File: attack_effect.gd
extends Area2D

signal hit_enemy(enemy_node: Node)

@onready var visual_sprite: Sprite2D = $AttackVisual 
@onready var lifetime_timer: Timer = $LifetimeTimer

var already_hit = false
var pending_direction_x: float = 1.0
var pending_attack_type: String = "horizontal"

func _ready():
	lifetime_timer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)
	
	if visual_sprite:
		apply_attack_direction()
	else:
		push_error("❌ AttackEffect _ready: visual_sprite node ('$AttackVisual') was NOT found!")

func _on_body_entered(body: Node):
	if already_hit:
		return

	# REMOVED: All logic for checking for "enemy_projectile" is gone.
	# The attack now only cares about hitting things in the "enemy" group.
	if body.is_in_group("enemy"):
		already_hit = true
		emit_signal("hit_enemy", body)
		queue_free()

func set_attack_direction(direction_x: float, attack_type: String = "horizontal"):
	pending_direction_x = direction_x
	pending_attack_type = attack_type
	if is_inside_tree() and visual_sprite:
		apply_attack_direction()
	elif not visual_sprite:
		push_error("❌ AttackEffect set_attack_direction: visual_sprite node ('$AttackVisual') was NOT found when called!")

func apply_attack_direction():
	if not visual_sprite:
		return
	visual_sprite.flip_h = false
	var rotation_angle = 0.0
	match pending_attack_type:
		"horizontal":
			if pending_direction_x < 0:
				rotation_angle = 180.0
			else:
				rotation_angle = 0.0
		"down":
			rotation_angle = 90.0
		"up":
			rotation_angle = -90.0
		_:
			push_warning("⚠️ AttackEffect: Received unknown pending_attack_type: '" + pending_attack_type + "'.")
	visual_sprite.rotation_degrees = rotation_angle
