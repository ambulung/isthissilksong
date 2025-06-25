# File: ranged_enemy.gd
extends CharacterBody2D

@export_group("Ranged Attack")
@export var projectile_scene: PackedScene
@export var shoot_cooldown: float = 3.0
@export var shoot_sound: AudioStream

@export_group("Core Stats & Effects")
@export var MAX_HEALTH: int = 80
@export var enemy_damage: int = 10
@export var blood_effect_scene: PackedScene
@export var damage_text_scene: PackedScene

@export_group("Audio")
@export var one_shot_audio_scene: PackedScene
@export var hit_sound: AudioStream
@export var death_sound: AudioStream

@export_group("Blood Splatter Settings")
@export var hit_splat_count: int = 15
@export var death_splat_count_1: int = 50
@export var death_splat_count_2: int = 30
@export var death_splat_delay: float = 0.1

@export_group("Enemy Movement")
@export var patrol_speed: float = 20.0
@export var patrol_distance: float = 100.0

@export_group("Enemy Damage & Invulnerability")
@export var INVINCIBILITY_DURATION_ENEMY: float = 0.5
@export var KNOCKBACK_FORCE_HORIZONTAL_ENEMY: float = 100.0
@export var KNOCKBACK_FORCE_VERTICAL_ENEMY: float = -80.0
@export var KNOCKBACK_DURATION_ENEMY: float = 0.15
@export var enemy_weight: float = 1.0

var current_health: int
var is_invincible: bool = false
var is_knocked_back: bool = false
var last_direction_x: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var damage_zone: Area2D = $DamageZone
@onready var patrol_start_position: Vector2 = global_position
@onready var shoot_timer: Timer = $ShootTimer

func _ready():
	add_to_group("enemy")
	current_health = MAX_HEALTH
	damage_zone.body_entered.connect(_on_damage_zone_body_entered)
	
	shoot_timer.wait_time = shoot_cooldown
	shoot_timer.timeout.connect(shoot)
	shoot_timer.start()
	
	velocity.x = patrol_speed
	update_animation()

func _physics_process(delta: float):
	velocity.y += 800 * delta

	if is_knocked_back:
		move_and_slide()
		return

	if abs(global_position.x - patrol_start_position.x) >= patrol_distance / 2.0:
		velocity.x *= -1.0
		global_position.x = clamp(global_position.x, patrol_start_position.x - patrol_distance / 2.0, patrol_start_position.x + patrol_distance / 2.0)
	
	if is_on_wall():
		velocity.x *= -1.0
	
	velocity.x = sign(velocity.x) * patrol_speed

	if velocity.x != 0:
		last_direction_x = sign(velocity.x)
	
	if animated_sprite:
		animated_sprite.flip_h = last_direction_x < 0
	
	move_and_slide()

func shoot():
	if not projectile_scene or is_knocked_back: return

	_play_one_shot_sound(shoot_sound, 0.9, 1.1)
	
	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	# CHANGED: This call is now simpler, as the projectile no longer needs to know who its shooter is.
	projectile.launch(global_position, Vector2(last_direction_x, 0))

# --- All other functions are unchanged ---
func update_animation():
	if not animated_sprite: return
	if animated_sprite.animation != "walk":
		animated_sprite.play("walk")

func _on_damage_zone_body_entered(body: Node):
	if body.is_in_group("player") and not is_knocked_back:
		if body.has_method("take_damage"):
			body.take_damage(enemy_damage, global_position)

func take_damage(amount: int, source_position: Vector2 = Vector2.INF):
	if is_invincible: return
	
	_spawn_damage_text(amount)
	_play_one_shot_sound(hit_sound, 0.8, 1.2)
	current_health -= amount
	
	if current_health <= 0:
		_die()
		return
		
	_spawn_blood_splatter(hit_splat_count, Color.RED, global_position)
	_start_invincibility()
	if source_position != Vector2.INF:
		_start_knockback(source_position)

func _spawn_damage_text(damage_amount: int):
	if not damage_text_scene: return
	var text_instance = damage_text_scene.instantiate() as Node2D
	get_tree().current_scene.add_child(text_instance)
	var random_offset = Vector2(randf_range(-15, 15), randf_range(-25, -15))
	text_instance.global_position = global_position + random_offset
	if text_instance.has_method("show_damage"):
		text_instance.show_damage(damage_amount)

func _start_knockback(source_position: Vector2):
	is_knocked_back = true
	velocity.x = 0
	var knockback_direction = (global_position - source_position).normalized()
	velocity.x = knockback_direction.x * (KNOCKBACK_FORCE_HORIZONTAL_ENEMY / max(0.1, enemy_weight))
	velocity.y = KNOCKBACK_FORCE_VERTICAL_ENEMY / max(0.1, enemy_weight)
	get_tree().create_timer(KNOCKBACK_DURATION_ENEMY).timeout.connect(_end_knockback)

func _end_knockback():
	is_knocked_back = false
	velocity.x = sign(last_direction_x) * patrol_speed

func _die():
	_play_one_shot_sound(death_sound, 0.7, 0.9)
	_spawn_blood_splatter(death_splat_count_1, Color.CRIMSON, global_position)
	var timer = get_tree().create_timer(death_splat_delay)
	timer.timeout.connect(func(): _spawn_blood_splatter(death_splat_count_2, Color.DARK_RED, global_position))
	hide()
	set_process(false)
	set_physics_process(false)
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if damage_zone.has_node("CollisionShape2D"):
		damage_zone.get_node("CollisionShape2D").set_deferred("disabled", true)
	if damage_zone.body_entered.is_connected(_on_damage_zone_body_entered):
		damage_zone.body_entered.disconnect(_on_damage_zone_body_entered)
	get_tree().create_timer(0.5).timeout.connect(queue_free)

func _spawn_blood_splatter(count: int, color: Color, position: Vector2):
	if not blood_effect_scene: return
	var blood_instance = blood_effect_scene.instantiate() as GPUParticles2D
	get_parent().add_child(blood_instance)
	blood_instance.global_position = position
	if blood_instance.has_method("setup_and_fire"):
		blood_instance.setup_and_fire(count, color)

func _play_one_shot_sound(sound_stream: AudioStream, min_pitch: float = 0.9, max_pitch: float = 1.1):
	if not one_shot_audio_scene or not sound_stream: return
	var audio_instance = one_shot_audio_scene.instantiate() as AudioStreamPlayer2D
	get_parent().add_child(audio_instance)
	audio_instance.global_position = global_position
	audio_instance.fire(sound_stream, randf_range(min_pitch, max_pitch))

func _start_invincibility():
	is_invincible = true
	if animated_sprite:
		var tween = create_tween()
		tween.set_loops(int(INVINCIBILITY_DURATION_ENEMY * 12.5))
		tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0.0), 0.04)
		tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1.0), 0.04)
		tween.finished.connect(_end_invincibility)
	else:
		get_tree().create_timer(INVINCIBILITY_DURATION_ENEMY).timeout.connect(_end_invincibility)

func _end_invincibility():
	is_invincible = false
	if animated_sprite:
		animated_sprite.modulate = Color(1, 1, 1, 1)
