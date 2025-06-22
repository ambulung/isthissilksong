extends CharacterBody2D

@export var MAX_HEALTH: int = 100
@export var enemy_damage: int = 10

@export var blood_effect_scene: PackedScene

# NEW: Export variables for audio
@export_group("Audio")
@export var one_shot_audio_scene: PackedScene # Reference to OneShotAudio.tscn
@export var hit_sound: AudioStream # The "impact" sound file
@export var death_sound: AudioStream # The "death" sound file

@export_group("Blood Splatter Settings")
@export var hit_splat_count: int = 15
@export var death_splat_count_1: int = 50
@export var death_splat_count_2: int = 30
@export var death_splat_delay: float = 0.1

@export_group("Enemy Movement")
@export var chase_speed: float = 50.0
@export var patrol_speed: float = 20.0
@export var patrol_distance: float = 100.0

@export_group("Enemy Damage & Invulnerability")
@export var INVINCIBILITY_DURATION_ENEMY: float = 0.5
@export var KNOCKBACK_FORCE_HORIZONTAL_ENEMY: float = 100.0
@export var KNOCKBACK_FORCE_VERTICAL_ENEMY: float = -80.0
@export var KNOCKBACK_DURATION_ENEMY: float = 0.15
@export var enemy_weight: float = 1.0
@export var push_resistance: float = 1.0

# Collision Layer Constants
const PLAYER_LAYER = 1
const GROUND_LAYER = 2
const ENEMY_LAYER = 3
const PLAYER_ATTACK_LAYER = 4

# Enemy State Variables
var current_health: int
var is_invincible: bool = false
var is_knocked_back: bool = false
var is_player_detected: bool = false

# References to child nodes
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D 
@onready var vision_area: Area2D = $VisionArea 
@onready var initial_position: Vector2 = global_position 


func _ready():
    current_health = MAX_HEALTH
    vision_area.body_entered.connect(_on_VisionArea_body_entered)
    vision_area.body_exited.connect(_on_VisionArea_body_exited)

func _physics_process(delta: float):
    velocity.y += 800 * delta 
    if is_knocked_back:
        pass 
    else:
        velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
        if is_player_detected:
            var player_node = get_tree().get_first_node_in_group("player")
            if player_node:
                var direction = (player_node.global_position - global_position).normalized()
                velocity.x = move_toward(velocity.x, direction.x * chase_speed, 200 * delta)
            else:
                is_player_detected = false
        else:
            if abs(global_position.x - initial_position.x) >= patrol_distance / 2:
                velocity.x *= -1 
                initial_position.x = global_position.x
            if velocity.x == 0:
                velocity.x = patrol_speed
            if abs(velocity.x) < patrol_speed:
                velocity.x = sign(velocity.x) * patrol_speed
    move_and_slide()
    for i in get_slide_collision_count():
        var collision = get_slide_collision(i)
        var collider = collision.get_collider()
        if collider and collider.is_in_group("player"):
            if collider.has_method("take_damage"):
                collider.take_damage(enemy_damage, global_position)
            break 
    update_animations()

# NEW: Helper function to play a one-shot sound at the enemy's location
func _play_one_shot_sound(sound_stream: AudioStream, min_pitch: float = 0.9, max_pitch: float = 1.1):
    # Ensure both the scene and the sound file are assigned
    if not one_shot_audio_scene or not sound_stream:
        push_warning("OneShotAudio scene or sound stream not assigned to enemy!")
        return
        
    # Create an instance of the one-shot audio player
    var audio_instance = one_shot_audio_scene.instantiate() as AudioStreamPlayer2D
    
    # Add it to the main scene tree so it's not deleted with the enemy
    get_parent().add_child(audio_instance)
    
    # Position it where the enemy is
    audio_instance.global_position = global_position
    
    # Calculate a random pitch
    var random_pitch = randf_range(min_pitch, max_pitch)
    
    # Tell the audio player to fire with the specified sound and pitch
    audio_instance.fire(sound_stream, random_pitch)


func take_damage(amount: int, source_position: Vector2 = Vector2.INF):
    if is_invincible:
        return

    # Play the hit sound
    _play_one_shot_sound(hit_sound, 0.8, 1.2)
        
    current_health -= amount
    
    if current_health <= 0:
        _die()
        return

    _spawn_blood_splatter(hit_splat_count, Color.RED, global_position)
    _start_invincibility()
    if source_position != Vector2.INF:
        _start_knockback(source_position)

func _spawn_blood_splatter(count: int, color: Color, position: Vector2):
    if not blood_effect_scene: return
    var blood_instance = blood_effect_scene.instantiate() as GPUParticles2D
    get_parent().add_child(blood_instance)
    blood_instance.global_position = position
    if blood_instance.has_method("setup_and_fire"):
        blood_instance.setup_and_fire(count, color)

func _die():
    print("Enemy defeated!")
    
    # Play the death sound
    _play_one_shot_sound(death_sound, 0.7, 0.9) # Lower pitch for a bigger feel
    
    _spawn_blood_splatter(death_splat_count_1, Color.CRIMSON, global_position)
    var timer = get_tree().create_timer(death_splat_delay)
    timer.timeout.connect(func(): _spawn_blood_splatter(death_splat_count_2, Color.DARK_RED, global_position))
    
    # Immediately hide the enemy sprite and disable its collision/processing
    hide()
    set_process(false)
    set_physics_process(false)
    if get_node("CollisionShape2D"):
        get_node("CollisionShape2D").set_deferred("disabled", true)
        
    # Wait a moment before fully removing the enemy node to let effects play out
    get_tree().create_timer(0.5).timeout.connect(queue_free)

func _start_invincibility():
    is_invincible = true
    set_collision_mask_value(PLAYER_ATTACK_LAYER, false) 
    if animated_sprite:
        var tween = create_tween()
        tween.set_loops(int(INVINCIBILITY_DURATION_ENEMY * 12.5)) 
        tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0.0), 0.04)
        tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1.0), 0.04)
        tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
        tween.finished.connect(_end_invincibility)
    else:
        get_tree().create_timer(INVINCIBILITY_DURATION_ENEMY).timeout.connect(_end_invincibility)

func _end_invincibility():
    is_invincible = false
    set_collision_mask_value(PLAYER_ATTACK_LAYER, true)
    if animated_sprite:
        animated_sprite.modulate = Color(1, 1, 1, 1)

func _start_knockback(source_position: Vector2):
    is_knocked_back = true
    var knockback_direction = (global_position - source_position).normalized()
    var calculated_horizontal_force = KNOCKBACK_FORCE_HORIZONTAL_ENEMY / max(0.1, enemy_weight)
    velocity.x = knockback_direction.x * calculated_horizontal_force
    var calculated_vertical_force = KNOCKBACK_FORCE_VERTICAL_ENEMY / max(0.1, enemy_weight)
    velocity.y = calculated_vertical_force 
    get_tree().create_timer(KNOCKBACK_DURATION_ENEMY).timeout.connect(_end_knockback)

func _end_knockback():
    is_knocked_back = false

func _on_VisionArea_body_entered(body: Node):
    if body.is_in_group("player"):
        is_player_detected = true

func _on_VisionArea_body_exited(body: Node):
    if body.is_in_group("player"):
        is_player_detected = false

func apply_push_force(force: float, direction: float):
    if is_knocked_back:
        return
    var push_force = force / max(0.1, push_resistance)
    velocity.x = push_force * direction

func update_animations():
    if not animated_sprite: return
    if velocity.x > 0.1:
        animated_sprite.flip_h = false
    elif velocity.x < -0.1:
        animated_sprite.flip_h = true
    var target_animation = ""
    if abs(velocity.x) > 5.0:
        target_animation = "walk"
    else:
        target_animation = "idle"
    if animated_sprite.animation != target_animation:
        animated_sprite.play(target_animation)
