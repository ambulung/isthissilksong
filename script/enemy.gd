extends CharacterBody2D

@export var MAX_HEALTH: int = 100
@export var enemy_damage: int = 10

@export var blood_effect_scene: PackedScene

@export_group("Audio")
@export var one_shot_audio_scene: PackedScene
@export var hit_sound: AudioStream
@export var death_sound: AudioStream
@export var alert_sound: AudioStream

@export_group("Blood Splatter Settings")
@export var hit_splat_count: int = 15
@export var death_splat_count_1: int = 50
@export var death_splat_count_2: int = 30
@export var death_splat_delay: float = 0.1

@export_group("Enemy Movement")
@export var patrol_speed: float = 20.0
@export var patrol_distance: float = 100.0
@export var alert_duration: float = 0.5
@export var charge_speed: float = 250.0
@export var charge_duration: float = 0.75
@export var charge_cooldown: float = 2.0

@export_group("Enemy Damage & Invulnerability")
@export var INVINCIBILITY_DURATION_ENEMY: float = 0.5
@export var KNOCKBACK_FORCE_HORIZONTAL_ENEMY: float = 100.0
@export var KNOCKBACK_FORCE_VERTICAL_ENEMY: float = -80.0
@export var KNOCKBACK_DURATION_ENEMY: float = 0.15
@export var enemy_weight: float = 1.0
@export var push_resistance: float = 1.0

enum { IDLE, ALERTED, CHARGING, COOLDOWN }
var state = IDLE

var current_health: int
var is_invincible: bool = false
var is_knocked_back: bool = false
var charge_target_position: Vector2

var alert_timer: SceneTreeTimer = null
var charge_timer: SceneTreeTimer = null
var cooldown_timer: SceneTreeTimer = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision_area: Area2D = $VisionArea
@onready var damage_zone: Area2D = $DamageZone
@onready var initial_position: Vector2 = global_position

func _ready():
	current_health = MAX_HEALTH
	_connect_vision_signals()
	damage_zone.body_entered.connect(_on_damage_zone_body_entered)
	change_state(IDLE)

func _physics_process(delta: float):
	velocity.y += 800 * delta
	if is_knocked_back:
		move_and_slide()
		return

	match state:
		IDLE: _state_idle(delta)
		ALERTED: _state_alerted(delta)
		CHARGING: _state_charging(delta)
		COOLDOWN: _state_cooldown(delta)

	move_and_slide()
	update_animations()

func _state_idle(_delta):
	if abs(global_position.x - initial_position.x) >= patrol_distance / 2:
		velocity.x *= -1
		initial_position.x = global_position.x
	if velocity.x == 0:
		velocity.x = patrol_speed
	if abs(velocity.x) < patrol_speed:
		velocity.x = sign(velocity.x) * patrol_speed
	if animated_sprite:
		animated_sprite.flip_h = velocity.x < 0

func _state_alerted(_delta):
	velocity.x = 0
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and animated_sprite:
		animated_sprite.flip_h = (player_node.global_position.x < global_position.x)

func _state_charging(_delta):
	velocity.x = sign(velocity.x) * charge_speed
	if animated_sprite:
		animated_sprite.flip_h = velocity.x < 0

func _state_cooldown(_delta):
	velocity.x = lerp(velocity.x, 0.0, 5.0 * _delta)

func change_state(new_state):
	if state == new_state:
		return

	if alert_timer and is_instance_valid(alert_timer):
		alert_timer.timeout.disconnect(_start_charge)
		alert_timer = null
	if charge_timer and is_instance_valid(charge_timer):
		charge_timer.timeout.disconnect(_start_cooldown)
		charge_timer = null
	cooldown_timer = null

	state = new_state

	match state:
		IDLE, ALERTED: _connect_vision_signals()
		CHARGING, COOLDOWN: _disconnect_vision_signals()

	match state:
		IDLE:
			pass
		ALERTED:
			_play_one_shot_sound(alert_sound, 1.0, 1.0)
			alert_timer = get_tree().create_timer(alert_duration)
			alert_timer.timeout.connect(_start_charge)
		CHARGING:
			_start_charge_logic()
		COOLDOWN:
			cooldown_timer = get_tree().create_timer(charge_cooldown)
			cooldown_timer.timeout.connect(_on_cooldown_finished)

func _start_charge():
	if state == ALERTED:
		change_state(CHARGING)

func _start_cooldown():
	if state == CHARGING:
		change_state(COOLDOWN)

func _on_cooldown_finished():
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node and vision_area.get_overlapping_bodies().has(player_node):
		change_state(ALERTED)
	else:
		change_state(IDLE)

func _start_charge_logic():
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		charge_target_position = player_node.global_position
		var direction = (charge_target_position - global_position).normalized()
		velocity.x = direction.x * charge_speed
		charge_timer = get_tree().create_timer(charge_duration)
		charge_timer.timeout.connect(_start_cooldown)
	else:
		change_state(IDLE)

func _on_damage_zone_body_entered(body: Node):
	if body.is_in_group("player") and not is_knocked_back:
		if body.has_method("take_damage"):
			body.take_damage(enemy_damage, global_position)

func take_damage(amount: int, source_position: Vector2 = Vector2.INF):
	if is_invincible:
		return
	_play_one_shot_sound(hit_sound, 0.8, 1.2)
	current_health -= amount
	if current_health <= 0:
		_die()
		return
	_spawn_blood_splatter(hit_splat_count, Color.RED, global_position)
	_start_invincibility()
	if source_position != Vector2.INF:
		_start_knockback(source_position)

func _start_knockback(source_position: Vector2):
	is_knocked_back = true
	change_state(IDLE)
	var knockback_direction = (global_position - source_position).normalized()
	velocity.x = knockback_direction.x * (KNOCKBACK_FORCE_HORIZONTAL_ENEMY / max(0.1, enemy_weight))
	velocity.y = KNOCKBACK_FORCE_VERTICAL_ENEMY / max(0.1, enemy_weight)
	get_tree().create_timer(KNOCKBACK_DURATION_ENEMY).timeout.connect(_end_knockback)

func _end_knockback():
	is_knocked_back = false
	change_state(COOLDOWN)

func _spawn_blood_splatter(count: int, color: Color, position: Vector2):
	if not blood_effect_scene:
		return
	var blood_instance = blood_effect_scene.instantiate() as GPUParticles2D
	get_parent().add_child(blood_instance)
	blood_instance.global_position = position
	if blood_instance.has_method("setup_and_fire"):
		blood_instance.setup_and_fire(count, color)

func _play_one_shot_sound(sound_stream: AudioStream, min_pitch: float = 0.9, max_pitch: float = 1.1):
	if not one_shot_audio_scene or not sound_stream:
		return
	var audio_instance = one_shot_audio_scene.instantiate() as AudioStreamPlayer2D
	get_parent().add_child(audio_instance)
	audio_instance.global_position = global_position
	audio_instance.fire(sound_stream, randf_range(min_pitch, max_pitch))

func _die():
	_play_one_shot_sound(death_sound, 0.7, 0.9)
	_spawn_blood_splatter(death_splat_count_1, Color.CRIMSON, global_position)
	var timer = get_tree().create_timer(death_splat_delay)
	timer.timeout.connect(func(): _spawn_blood_splatter(death_splat_count_2, Color.DARK_RED, global_position))

	hide()
	set_process(false)
	set_physics_process(false)

	# ✅ Disable body collision
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)

	# ✅ Disable damage zone collision
	if damage_zone.has_node("CollisionShape2D"):
		damage_zone.get_node("CollisionShape2D").set_deferred("disabled", true)

	# ✅ Disconnect signal to be safe
	if damage_zone.body_entered.is_connected(_on_damage_zone_body_entered):
		damage_zone.body_entered.disconnect(_on_damage_zone_body_entered)

	get_tree().create_timer(0.5).timeout.connect(queue_free)

func _start_invincibility():
	is_invincible = true
	set_collision_mask_value(4, false)
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
	set_collision_mask_value(4, true)
	if animated_sprite:
		animated_sprite.modulate = Color(1, 1, 1, 1)

func apply_push_force(force: float, direction: float):
	if is_knocked_back:
		return
	velocity.x = (force / max(0.1, push_resistance)) * direction

func _connect_vision_signals():
	if not vision_area.body_entered.is_connected(_on_VisionArea_body_entered):
		vision_area.body_entered.connect(_on_VisionArea_body_entered)
	if not vision_area.body_exited.is_connected(_on_VisionArea_body_exited):
		vision_area.body_exited.connect(_on_VisionArea_body_exited)

func _disconnect_vision_signals():
	if vision_area.body_entered.is_connected(_on_VisionArea_body_entered):
		vision_area.body_entered.disconnect(_on_VisionArea_body_entered)
	if vision_area.body_exited.is_connected(_on_VisionArea_body_exited):
		vision_area.body_exited.disconnect(_on_VisionArea_body_exited)

func _on_VisionArea_body_entered(body: Node):
	if body.is_in_group("player") and state == IDLE and not is_knocked_back:
		change_state(ALERTED)

func _on_VisionArea_body_exited(body: Node):
	if body.is_in_group("player") and state == ALERTED:
		change_state(IDLE)

func update_animations():
	if not animated_sprite:
		return
	var target_animation = ""
	match state:
		IDLE: target_animation = "walk"
		ALERTED: target_animation = "idle"
		CHARGING: target_animation = "walk"
		COOLDOWN: target_animation = "idle"
	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)
