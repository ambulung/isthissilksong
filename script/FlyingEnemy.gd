extends CharacterBody2D

@export var MAX_HEALTH: int = 50
@export var speed: float = 120.0
@export var damage: int = 15

@export_group("Chase Settings")
@export var detection_radius: float = 200.0
@export var follow_distance: float = 400.0
@export var stop_chase_distance: float = 16.0

@export_group("Patrol Settings")
@export var patrol_pause_duration: float = 0.5
@export var patrol_points: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)]
@export var hover_amplitude: float = 10.0
@export var hover_speed: float = 2.0

@export_group("Knockback")
@export var knockback_force: float = 150.0
@export var knockback_duration: float = 0.2
@export var invincibility_duration: float = 0.5

# <--- ADDED: Assign your DamageText.tscn and other scenes here
@export var blood_effect_scene: PackedScene
@export var damage_text_scene: PackedScene 
@export var one_shot_audio_scene: PackedScene
@export var hit_sound: AudioStream
@export var death_sound: AudioStream

@onready var vision_area: Area2D = $VisionArea
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_zone: Area2D = $DamageZone

var target: Node = null
var current_health: int
var is_invincible = false
var is_knocked_back = false

var patrol_index := 0
var is_pausing := false
var hover_timer := 0.0
var initial_position: Vector2
var patrol_positions: Array[Vector2] = []

func _ready():
	current_health = MAX_HEALTH
	initial_position = global_position
	for i in patrol_points:
		patrol_positions.append(initial_position + i)

	vision_area.body_entered.connect(_on_body_entered)
	vision_area.body_exited.connect(_on_body_exited)

func _physics_process(delta):
	if is_knocked_back:
		move_and_slide()
		return

	_check_damage_zone()

	if target and is_instance_valid(target):
		var to_target = target.global_position - global_position
		if to_target.length() > follow_distance:
			target = null
		elif to_target.length() > stop_chase_distance:
			velocity = to_target.normalized() * speed
		else:
			velocity = Vector2.ZERO
		animated_sprite.flip_h = velocity.x < 0
	else:
		_patrol(delta)

	move_and_slide()
	update_animation()

func _patrol(delta):
	if is_pausing or patrol_positions.is_empty():
		velocity = Vector2.ZERO
		return

	hover_timer += delta
	var target_position = patrol_positions[patrol_index]
	var to_target = target_position - global_position
	if to_target.length() < 4.0:
		is_pausing = true
		velocity = Vector2.ZERO
		get_tree().create_timer(patrol_pause_duration).timeout.connect(_on_patrol_pause_done)
		return

	velocity = to_target.normalized() * speed
	velocity.y += sin(hover_timer * hover_speed * TAU) * hover_amplitude
	animated_sprite.flip_h = velocity.x < 0

func _on_patrol_pause_done():
	patrol_index = (patrol_index + 1) % patrol_positions.size()
	is_pausing = false

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		target = body

func _on_body_exited(body: Node):
	if body == target:
		target = null

func _check_damage_zone():
	for body in damage_zone.get_overlapping_bodies():
		if body.is_in_group("player") and not is_knocked_back:
			if body.has_method("take_damage"):
				body.take_damage(damage, global_position)
				start_knockback(body.global_position)

func take_damage(amount: int, source_position: Vector2 = Vector2.INF):
	if is_invincible:
		return
		
	# <--- MODIFIED: Spawn the damage text when damage is taken
	_spawn_damage_text(amount)
	
	_play_sound(hit_sound, 0.9, 1.1)
	current_health -= amount
	if current_health <= 0:
		die()
	else:
		_spawn_blood()
		start_invincibility()
		if source_position != Vector2.INF:
			start_knockback(source_position)

# <--- ADDED: This new function spawns and configures the damage text
func _spawn_damage_text(damage_amount: int):
	if not damage_text_scene:
		return
		
	var text_instance = damage_text_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(text_instance)
	
	var random_offset = Vector2(randf_range(-15, 15), randf_range(-25, -15))
	text_instance.global_position = global_position + random_offset
	
	if text_instance.has_method("show_damage"):
		text_instance.show_damage(damage_amount)

func start_knockback(source_position: Vector2):
	is_knocked_back = true
	var dir = (global_position - source_position).normalized()
	velocity = dir * knockback_force
	get_tree().create_timer(knockback_duration).timeout.connect(end_knockback)

func end_knockback():
	is_knocked_back = false

func start_invincibility():
	is_invincible = true
	if animated_sprite:
		var tween = create_tween()
		tween.set_loops(int(invincibility_duration * 12.5))
		tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0), 0.04)
		tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1), 0.04)
		tween.finished.connect(end_invincibility)

func end_invincibility():
	is_invincible = false
	if animated_sprite:
		animated_sprite.modulate = Color(1, 1, 1, 1)

func die():
	_play_sound(death_sound, 0.7, 0)
	_spawn_blood()
	if has_node("CollisionShape2D"): # Safer check
		$CollisionShape2D.set_deferred("disabled", true)
	if damage_zone.has_node("CollisionShape2D"):
		$DamageZone/CollisionShape2D.set_deferred("disabled", true)
	# A small delay before freeing can prevent some race condition errors
	get_tree().create_timer(0.01).timeout.connect(queue_free)

func _spawn_blood():
	if not blood_effect_scene:
		return
	var blood = blood_effect_scene.instantiate()
	get_parent().add_child(blood)
	blood.global_position = global_position
	if blood.has_method("setup_and_fire"):
		blood.setup_and_fire(10, Color.RED)

func _play_sound(stream: AudioStream, min_pitch: float, max_pitch: float):
	if not one_shot_audio_scene or not stream:
		return
	var audio = one_shot_audio_scene.instantiate()
	get_parent().add_child(audio)
	audio.global_position = global_position
	if audio.has_method("fire"):
		audio.fire(stream, randf_range(min_pitch, max_pitch))

func update_animation():
	if not animated_sprite:
		return
	if velocity.length() > 5:
		animated_sprite.play("fly")
	else:
		animated_sprite.play("idle")
