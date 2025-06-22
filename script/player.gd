extends CharacterBody2D

################################################################################
#                                MOVEMENT SETTINGS                              #
################################################################################

@export_group("Horizontal Movement")
@export var SPEED: float = 150.0       # Max horizontal movement speed
@export var ACCELERATION: float = 10.0 # How quickly the player reaches max speed
@export var FRICTION: float = 15.0     # How quickly the player slows down when no input

@export_group("Jumping")
@export var JUMP_VELOCITY: float = -300.0 # Initial upward velocity for jump (negative because Y is down)
@export var GRAVITY: float = 800.0       # Downward force acting on the player
@export var JUMP_CUT_MULTIPLIER: float = 0.5 # Multiplier for variable jump height (e.g., 0.5 means half height if jump released early)
@export var BOUNCE_VELOCITY_MULTIPLIER: float = 0.8 # Multiplier for the bounce off enemy (can be less than 1 or more)

@export_group("Jump Forgiveness")
@export var COYOTE_TIME: float = 0.1   # Time after leaving ground to still jump (in seconds)
@export var JUMP_BUFFER_TIME: float = 0.15 # Time before landing to pre-press jump (in seconds)

@export_group("Attack")
@export var attack_sprite_scene: PackedScene # Reference to your AttackEffect.tscn
@export var attack_cooldown: float = 0.5   # Time between attacks
@export var attack_offset_x: float = 20.0  # How far in front of the player the horizontal attack sprite spawns
@export var down_attack_offset_y: float = 20.0 # How far below the player the down attack sprite spawns
@export var up_attack_offset_y: float = -20.0 # How far above the player the up attack sprite spawns (negative Y is up)
@export var attack_damage: int = 10 # Damage value for attacks

@export_group("Dodge")
@export var DODGE_SPEED: float = 400.0   # Speed of the dodge dash
@export var DODGE_DURATION: float = 0.2  # How long the dodge dash lasts
@export var DODGE_COOLDOWN: float = 1.0  # Time before player can dodge again
@export var DODGE_ROTATION_DEGREES: float = 360.0 # Degrees to rotate during dodge

@export_group("Damage & Invulnerability")
@export var MAX_HEALTH: int = 100
@export var INVINCIBILITY_DURATION: float = 1.0 # How long player is invulnerable after taking damage
@export var KNOCKBACK_FORCE_HORIZONTAL: float = 250.0 # Horizontal force of knockback
@export var KNOCKBACK_FORCE_VERTICAL: float = -150.0 # Vertical force of knockback (negative for upward knockback)
@export var KNOCKBACK_DURATION: float = 0.25 # How long knockback velocity is applied

@export_group("Hit Effects")
@export var hit_stop_duration: float = 0.08 # Duration of the game pause in seconds
@export var hit_zoom_amount: float = 0.95 # How much to zoom in (e.g., 0.95 is a 5% zoom). Closer to 0 is more zoom.
@export var hit_zoom_duration: float = 0.1 # How long the zoom in/out effect takes
@export var player_blood_effect_scene: PackedScene
@export var player_hit_splat_count: int = 20

################################################################################
#                                  NODES & STATE                                #
################################################################################

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
# NEW: Reference to the player's attack sound player
@onready var attack_sound_player: AudioStreamPlayer2D = $AttackSoundPlayer

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var last_direction_x: float = 1.0
var can_attack: bool = true
var is_in_attack_animation: bool = false

var is_dodging: bool = false
var can_dodge: bool = true

var current_health: int
var is_invincible: bool = false
var is_knocked_back: bool = false

# Assuming Player is Layer 1, Enemy is Layer 3
const PLAYER_LAYER = 1
const ENEMY_LAYER = 3

################################################################################
#                                  LIFECYCLE METHODS                            #
################################################################################

func _ready():
    animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
    current_health = MAX_HEALTH
    print("Player initialized.")

func _physics_process(delta: float):
    velocity.y += GRAVITY * delta

    if Input.is_action_just_pressed("dodge") and can_dodge and not is_dodging and not is_knocked_back:
        perform_dodge()
        return

    if not is_dodging:
        if is_knocked_back:
            pass
        else:
            var input_direction_x = Input.get_axis("left", "right")
            if input_direction_x != 0:
                velocity.x = lerp(velocity.x, input_direction_x * SPEED, ACCELERATION * delta)
                last_direction_x = input_direction_x
            else:
                velocity.x = lerp(velocity.x, 0.0, FRICTION * delta)
                if abs(velocity.x) < 5:
                    velocity.x = 0.0

            if is_on_floor():
                coyote_timer = COYOTE_TIME
            else:
                coyote_timer -= delta

            if Input.is_action_just_pressed("jump"):
                jump_buffer_timer = JUMP_BUFFER_TIME
            else:
                jump_buffer_timer -= delta

            if jump_buffer_timer > 0 and coyote_timer > 0:
                velocity.y = JUMP_VELOCITY
                coyote_timer = 0.0
                jump_buffer_timer = 0.0

            if Input.is_action_just_released("jump") and velocity.y < 0:
                velocity.y *= JUMP_CUT_MULTIPLIER

            if Input.is_action_just_pressed("attack") and can_attack and not is_in_attack_animation:
                if Input.is_action_pressed("up"):
                    perform_up_attack()
                elif not is_on_floor() and Input.is_action_pressed("down") and velocity.y >= 0:
                    perform_down_attack()
                else:
                    perform_horizontal_attack()
    else:
        velocity.x = last_direction_x * DODGE_SPEED

    move_and_slide()
    update_animations()

################################################################################
#                                  ATTACK LOGIC                                 #
################################################################################

# NEW: Helper function to play the attack sound with random pitch
func _play_attack_sound():
    if attack_sound_player:
        # Randomize the pitch slightly for variation (e.g., between 90% and 110%)
        attack_sound_player.pitch_scale = randf_range(0.9, 1.1)
        attack_sound_player.play()

func perform_horizontal_attack():
    if not attack_sprite_scene: return
    _play_attack_sound()
    can_attack = false
    is_in_attack_animation = true
    var attack_instance = attack_sprite_scene.instantiate()
    attack_instance.global_position = global_position + Vector2(last_direction_x * attack_offset_x, 0)
    if attack_instance.has_method("set_attack_direction"):
        attack_instance.call_deferred("set_attack_direction", last_direction_x, "horizontal")
    get_parent().add_child(attack_instance)
    attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "horizontal"))
    start_attack_cooldown()
    animated_sprite.play("attack")

func perform_down_attack():
    if not attack_sprite_scene: return
    _play_attack_sound()
    can_attack = false
    is_in_attack_animation = true
    var attack_instance = attack_sprite_scene.instantiate()
    attack_instance.global_position = global_position + Vector2(0, down_attack_offset_y)
    if attack_instance.has_method("set_attack_direction"):
        attack_instance.call_deferred("set_attack_direction", last_direction_x, "down")
    get_parent().add_child(attack_instance)
    attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "down"))
    start_attack_cooldown()
    animated_sprite.play("down_attack")

func perform_up_attack():
    if not attack_sprite_scene: return
    _play_attack_sound()
    can_attack = false
    is_in_attack_animation = true
    var attack_instance = attack_sprite_scene.instantiate()
    attack_instance.global_position = global_position + Vector2(0, up_attack_offset_y)
    if attack_instance.has_method("set_attack_direction"):
        attack_instance.call_deferred("set_attack_direction", last_direction_x, "up")
    get_parent().add_child(attack_instance)
    attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "up"))
    start_attack_cooldown()
    animated_sprite.play("up_attack")

func start_attack_cooldown():
    get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)

func _on_attack_effect_hit_enemy(enemy_node: Node, attack_type: String):
    _trigger_hit_effects()
    if enemy_node and enemy_node.has_method("take_damage"):
        enemy_node.take_damage(attack_damage, global_position)
        if attack_type == "down":
            velocity.y = JUMP_VELOCITY * BOUNCE_VELOCITY_MULTIPLIER
        elif attack_type == "up":
            velocity.y = 0 

################################################################################
#                                  DODGE LOGIC                                  #
################################################################################

func perform_dodge():
    is_dodging = true
    can_dodge = false
    set_collision_mask_value(ENEMY_LAYER, false)
    set_collision_layer_value(PLAYER_LAYER, false)
    velocity.x = last_direction_x * DODGE_SPEED
    var tween = create_tween()
    tween.tween_property(animated_sprite, "rotation_degrees", 
        animated_sprite.rotation_degrees + (DODGE_ROTATION_DEGREES * last_direction_x), 
        DODGE_DURATION)
    tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    get_tree().create_timer(DODGE_DURATION).timeout.connect(_end_dodge)
    animated_sprite.play("dodge")

func _end_dodge():
    is_dodging = false
    set_collision_mask_value(ENEMY_LAYER, true)
    set_collision_layer_value(PLAYER_LAYER, true)
    animated_sprite.rotation_degrees = 0 
    get_tree().create_timer(DODGE_COOLDOWN).timeout.connect(func(): can_dodge = true)
    update_animations()

################################################################################
#                             DAMAGE & INVULNERABILITY                          #
################################################################################

func take_damage(amount: int, source_position: Vector2):
    if is_invincible or is_dodging: return
    _trigger_hit_effects()
    _spawn_blood_splatter(player_hit_splat_count, Color.RED, global_position)
    current_health -= amount
    print("Player took ", amount, " damage. Current Health: ", current_health)
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
    print("Player has been defeated!")
    _spawn_blood_splatter(player_hit_splat_count * 2, Color.CRIMSON, global_position)
    set_physics_process(false) 
    queue_free()

################################################################################
#                              HIT EFFECTS LOGIC                                #
################################################################################

func _trigger_hit_effects():
    var camera = get_tree().get_first_node_in_group("camera")
    if camera:
        var original_zoom = camera.zoom
        var tween = get_tree().create_tween().set_ignore_time_scale(true)
        tween.tween_property(camera, "zoom", original_zoom * hit_zoom_amount, hit_zoom_duration / 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tween.tween_property(camera, "zoom", original_zoom, hit_zoom_duration / 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    
    if hit_stop_duration > 0:
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

################################################################################
#                                  ANIMATION LOGIC                              #
################################################################################

func update_animations():
    if not animated_sprite: return 
    animated_sprite.flip_h = last_direction_x < 0
    
    if is_dodging:
        if animated_sprite.animation != "dodge" or not animated_sprite.is_playing():
            animated_sprite.play("dodge") 
        return 
    
    if is_in_attack_animation:
        return
    
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
