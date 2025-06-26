# File: player.gd
extends CharacterBody2D

signal health_updated(current_health, max_health)

@export_group("Horizontal Movement")
@export var SPEED: float = 150.0
@export var ACCELERATION: float = 10.0
@export var FRICTION: float = 15.0
@export_group("Jumping")
@export var JUMP_VELOCITY: float = -300.0
@export var GRAVITY: float = 800.0
@export var JUMP_CUT_MULTIPLIER: float = 0.5
@export var BOUNCE_VELOCITY_MULTIPLIER: float = 0.8
@export_group("Jump Forgiveness")
@export var COYOTE_TIME: float = 0.1
@export var JUMP_BUFFER_TIME: float = 0.15
@export_group("Grapple")
@export var grapple_cooldown: float = 0.5
@export var grapple_needle_scene: PackedScene
@export var GRAPPLE_PULL_SPEED: float = 450.0
@export var GRAPPLE_MAX_DISTANCE: float = 600.0
@export_group("Attack")
@export var attack_sprite_scene: PackedScene
@export var attack_cooldown: float = 0.5
@export var attack_offset_x: float = 20.0
@export var down_attack_offset_y: float = 20.0
@export var up_attack_offset_y: float = -20.0
@export var attack_damage: int = 10
@export_group("Damage & Invulnerability")
@export var MAX_HEALTH: int = 100
@export var INVINCIBILITY_DURATION: float = 1.0
@export var KNOCKBACK_FORCE_HORIZONTAL: float = 250.0
@export var KNOCKBACK_FORCE_VERTICAL: float = -150.0
@export var KNOCKBACK_DURATION: float = 0.25
@export_group("Hit Effects")
@export var hit_stop_duration: float = 0.08
@export var hit_zoom_amount: float = 0.95
@export var hit_zoom_duration: float = 0.1
@export var player_blood_effect_scene: PackedScene
@export var player_hit_splat_count: int = 20
@export_group("Respawn")
@export var respawn_sprite_delay: float = 0.2

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_sound_player: AudioStreamPlayer2D = $AttackSoundPlayer
@onready var grapple_rope: Line2D = $GrappleRope
@onready var hazard_detector: Area2D = $HazardDetector

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var last_direction_x: float = 1.0
var can_attack: bool = true
var is_in_attack_animation: bool = false
var current_health: int
var is_invincible: bool = false
var is_knocked_back: bool = false
var is_grappling: bool = false
var is_needle_out: bool = false
var _grapple_jump_available: bool = true
var _is_grapple_on_cooldown: bool = false
var grapple_point: Vector2 = Vector2.ZERO
var needle_instance: Node = null
var is_respawning: bool = false

const ENEMY_LAYER = 3

# --- STATE MANAGEMENT ---
func save_state():
	Global.player_data.current_health = current_health
	Global.player_data.max_health = MAX_HEALTH

func load_state():
	self.current_health = Global.player_data.current_health
	self.MAX_HEALTH = Global.player_data.max_health
	health_updated.emit(current_health, MAX_HEALTH)

func set_facing_direction(direction: int):
	if direction in [-1, 1]:
		self.last_direction_x = direction
		update_animations()

# --- INITIALIZATION ---
func _ready():
	add_to_group("player")
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	SceneFader.faded_to_black.connect(_handle_respawn_sequence)
	grapple_rope.clear_points()
	load_state()
	if Global.current_checkpoint_position == Vector2.ZERO:
		Global.current_checkpoint_position = global_position

# --- CORE LOGIC ---
func _physics_process(delta: float):
	if is_respawning:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("grapple"):
		if is_grappling or is_needle_out: _release_grapple()
		else: _launch_needle()
	if Input.is_action_just_pressed("attack") and can_attack and not is_in_attack_animation:
		if Input.is_action_pressed("up"): perform_up_attack()
		elif not is_on_floor() and Input.is_action_pressed("down") and velocity.y >= 0: perform_down_attack()
		else: perform_horizontal_attack()
	var jump_pressed_this_frame = Input.is_action_just_pressed("jump")
	if jump_pressed_this_frame and is_grappling and _grapple_jump_available: _perform_grapple_jump()
	if is_grappling:
		var direction_to_grapple = (grapple_point - global_position).normalized()
		velocity = direction_to_grapple * GRAPPLE_PULL_SPEED
		if global_position.distance_to(grapple_point) < 20.0: _release_grapple()
	else:
		velocity.y += GRAVITY * delta
		if is_knocked_back: pass
		else:
			var input_direction_x = Input.get_axis("left", "right")
			if input_direction_x != 0:
				velocity.x = lerp(velocity.x, input_direction_x * SPEED, ACCELERATION * delta)
				last_direction_x = input_direction_x
			else:
				velocity.x = lerp(velocity.x, 0.0, FRICTION * delta)
			if is_on_floor():
				coyote_timer = COYOTE_TIME
				_grapple_jump_available = true
			else: coyote_timer -= delta
			if jump_pressed_this_frame: jump_buffer_timer = JUMP_BUFFER_TIME
			else: jump_buffer_timer -= delta
			if jump_buffer_timer > 0 and coyote_timer > 0:
				velocity.y = JUMP_VELOCITY
				coyote_timer = 0.0
				jump_buffer_timer = 0.0
			if Input.is_action_just_released("jump") and velocity.y < 0:
				velocity.y *= JUMP_CUT_MULTIPLIER
	move_and_slide()
	update_animations()
	_update_grapple_rope()

# --- HAZARD AND RESPAWN LOGIC ---

func _on_hazard_detector_body_entered(body: Node2D):
	_handle_hazard_hit()

func _handle_hazard_hit():
	"""A dedicated function for hazards that IGNORES invincibility frames."""
	if is_respawning:
		return

	is_respawning = true
	
	# Manually apply effects and damage, bypassing the main take_damage function.
	_trigger_hit_effects()
	_spawn_blood_splatter(player_hit_splat_count, Color.RED, global_position)
	current_health -= 10
	health_updated.emit(current_health, MAX_HEALTH)

	if current_health > 0:
		SceneFader.respawn_fade()
	else:
		is_respawning = false # Unlock flag before calling die
		_die()

func _handle_respawn_sequence():
	respawn()
	animated_sprite.visible = false
	await get_tree().create_timer(respawn_sprite_delay).timeout
	animated_sprite.visible = true
	is_respawning = false

func respawn():
	global_position = Global.current_checkpoint_position
	velocity = Vector2.ZERO
	is_knocked_back = false
	if is_grappling or is_needle_out: _release_grapple()
	print("Player respawned at ", global_position)

# --- GRAPPLE FUNCTIONS ---
func _perform_grapple_jump():
	_release_grapple()
	velocity.y = JUMP_VELOCITY
	_grapple_jump_available = false
	coyote_timer = 0.0
	jump_buffer_timer = 0.0

func _launch_needle():
	if not grapple_needle_scene or is_needle_out or _is_grapple_on_cooldown: return
	_is_grapple_on_cooldown = true
	get_tree().create_timer(grapple_cooldown).timeout.connect(_end_grapple_cooldown)
	is_needle_out = true
	needle_instance = grapple_needle_scene.instantiate()
	get_parent().add_child(needle_instance)
	needle_instance.stuck.connect(_on_needle_stuck)
	var direction = Vector2(last_direction_x, 0)
	needle_instance.launch(global_position, direction, GRAPPLE_MAX_DISTANCE)

func _end_grapple_cooldown():
	_is_grapple_on_cooldown = false

func _on_needle_stuck(attach_position: Vector2):
	grapple_point = attach_position
	is_grappling = true
	velocity.y = 0

func _release_grapple():
	is_grappling = false
	is_needle_out = false
	grapple_rope.clear_points()
	if is_instance_valid(needle_instance): needle_instance.queue_free()
	needle_instance = null
	if velocity.y > 0: velocity.y = 0

func _update_grapple_rope():
	if is_needle_out or is_grappling:
		if is_instance_valid(needle_instance):
			grapple_rope.clear_points()
			grapple_rope.add_point(Vector2.ZERO)
			grapple_rope.add_point(needle_instance.global_position - global_position)
		elif is_grappling:
			grapple_rope.clear_points()
			grapple_rope.add_point(Vector2.ZERO)
			grapple_rope.add_point(grapple_point - global_position)
		else: grapple_rope.clear_points()
	else: grapple_rope.clear_points()

# --- ATTACK FUNCTIONS ---
func _play_attack_sound():
	if attack_sound_player:
		attack_sound_player.pitch_scale = randf_range(0.9, 1.1)
		attack_sound_player.play()

func perform_horizontal_attack():
	var was_grappling = is_grappling
	if was_grappling or is_needle_out: _release_grapple()
	if not attack_sprite_scene: return
	_play_attack_sound()
	can_attack = false
	is_in_attack_animation = true
	var attack_instance = attack_sprite_scene.instantiate()
	get_parent().add_child(attack_instance)
	attack_instance.global_position = global_position + Vector2(last_direction_x * attack_offset_x, 0)
	if attack_instance.has_method("set_attack_direction"):
		attack_instance.set_attack_direction(last_direction_x, "horizontal")
	attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "horizontal", was_grappling))
	start_attack_cooldown()
	animated_sprite.play("attack")

func perform_down_attack():
	var was_grappling = is_grappling
	if was_grappling or is_needle_out: _release_grapple()
	if not attack_sprite_scene: return
	_play_attack_sound()
	can_attack = false
	is_in_attack_animation = true
	var attack_instance = attack_sprite_scene.instantiate()
	get_parent().add_child(attack_instance)
	attack_instance.global_position = global_position + Vector2(0, down_attack_offset_y)
	if attack_instance.has_method("set_attack_direction"):
		attack_instance.set_attack_direction(last_direction_x, "down")
	attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "down", was_grappling))
	start_attack_cooldown()
	animated_sprite.play("down_attack")

func perform_up_attack():
	var was_grappling = is_grappling
	if was_grappling or is_needle_out: _release_grapple()
	if not attack_sprite_scene: return
	_play_attack_sound()
	can_attack = false
	is_in_attack_animation = true
	var attack_instance = attack_sprite_scene.instantiate()
	get_parent().add_child(attack_instance)
	attack_instance.global_position = global_position + Vector2(0, up_attack_offset_y)
	if attack_instance.has_method("set_attack_direction"):
		attack_instance.set_attack_direction(last_direction_x, "up")
	attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "up", was_grappling))
	start_attack_cooldown()
	animated_sprite.play("up_attack")

func start_attack_cooldown():
	get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)

func _on_attack_effect_hit_enemy(enemy_node: Node, attack_type: String, from_grapple: bool):
	_trigger_hit_effects()
	if enemy_node and enemy_node.has_method("take_damage"):
		var current_attack_damage = attack_damage
		if from_grapple: current_attack_damage *= 3
		enemy_node.take_damage(current_attack_damage, global_position)
		if attack_type == "down": velocity.y = JUMP_VELOCITY * BOUNCE_VELOCITY_MULTIPLIER
		elif attack_type == "up": velocity.y = 0

# --- DAMAGE & HEALTH FUNCTIONS ---

func take_damage(amount: int, source_position: Vector2):
	"""This is for COMBAT damage and respects invincibility frames."""
	if is_invincible: return

	if is_grappling or is_needle_out: _release_grapple()
	_trigger_hit_effects()
	_spawn_blood_splatter(player_hit_splat_count, Color.RED, global_position)
	current_health -= amount
	health_updated.emit(current_health, MAX_HEALTH)
	if current_health <= 0:
		_die()
		return
	_start_invincibility()
	_start_knockback(source_position)

func _start_invincibility():
	is_invincible = true
	set_collision_mask_value(ENEMY_LAYER, false)
	var tween = create_tween()
	tween.set_loops(int(INVINCIBILITY_DURATION * 12.5)) 
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0.5), 0.04) 
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1.0), 0.04) 
	tween.finished.connect(_end_invincibility)

func _end_invincibility():
	is_invincible = false
	set_collision_mask_value(ENEMY_LAYER, true)
	animated_sprite.modulate = Color(1, 1, 1, 1)

func _start_knockback(source_position: Vector2):
	is_knocked_back = true
	var knockback_direction = (global_position - source_position).normalized()
	velocity.x = knockback_direction.x * KNOCKBACK_FORCE_HORIZONTAL
	velocity.y = KNOCKBACK_FORCE_VERTICAL 
	get_tree().create_timer(KNOCKBACK_DURATION).timeout.connect(_end_knockback)

func _end_knockback():
	is_knocked_back = false
	update_animations()

func _die():
	is_respawning = false
	print("Player has been defeated!")
	_spawn_blood_splatter(player_hit_splat_count * 2, Color.CRIMSON, global_position)
	set_physics_process(false) 
	health_updated.emit(0, MAX_HEALTH)
	queue_free()

# --- EFFECTS & ANIMATION ---

func _trigger_hit_effects():
	var camera = get_tree().get_first_node_in_group("camera")
	if camera:
		var original_zoom = camera.zoom
		var tween = get_tree().create_tween().set_ignore_time_scale(true)
		tween.tween_property(camera, "zoom", original_zoom * hit_zoom_amount, hit_zoom_duration / 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(camera, "zoom", original_zoom, hit_zoom_duration / 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
	if hit_stop_duration > 0 and not is_respawning:
		Engine.time_scale = 0.001
		var hit_stop_timer = get_tree().create_timer(hit_stop_duration, false, false, true)
		hit_stop_timer.timeout.connect(func(): Engine.time_scale = 1.0)

func _spawn_blood_splatter(count: int, color: Color, position: Vector2):
	if not player_blood_effect_scene:
		push_warning("Player Blood Effect Scene not assigned!")
		return
	var blood_instance = player_blood_effect_scene.instantiate() as GPUParticles2D
	get_parent().add_child(blood_instance)
	blood_instance.global_position = position
	if blood_instance.has_method("setup_and_fire"):
		blood_instance.setup_and_fire(count, color)

func update_animations():
	if not animated_sprite: return 
	animated_sprite.flip_h = last_direction_x < 0
	if is_grappling:
		if animated_sprite.animation != "jump": animated_sprite.play("jump")
		return
	if is_in_attack_animation: return
	var target_animation = ""
	if not is_on_floor():
		target_animation = "jump" if velocity.y < 0 else "fall"
	else:
		target_animation = "walk" if abs(velocity.x) > 10 else "idle"
	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

func _on_animated_sprite_animation_finished():
	if animated_sprite.animation in ["attack", "down_attack", "up_attack"]:
		is_in_attack_animation = false 
		update_animations()
