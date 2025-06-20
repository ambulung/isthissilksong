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
@export var attack_damage: int = 10 # Damage value for attacks

@export_group("Dodge")
@export var DODGE_SPEED: float = 400.0   # Speed of the dodge dash
@export var DODGE_DURATION: float = 0.2  # How long the dodge dash lasts
@export var DODGE_COOLDOWN: float = 1.0  # Time before player can dodge again
@export var DODGE_ROTATION_DEGREES: float = 360.0 # Degrees to rotate during dodge (e.g., 360 for one full spin)

@export_group("Damage & Invulnerability")
@export var MAX_HEALTH: int = 100
@export var INVINCIBILITY_DURATION: float = 1.0 # How long player is invulnerable after taking damage
@export var KNOCKBACK_FORCE_HORIZONTAL: float = 250.0 # Horizontal force of knockback
@export var KNOCKBACK_FORCE_VERTICAL: float = -150.0 # Vertical force of knockback (negative for upward knockback)
@export var KNOCKBACK_DURATION: float = 0.25 # How long knockback velocity is applied

################################################################################
#                                  NODES & STATE                                #
################################################################################

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # Assuming you have a CollisionShape2D child

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var last_direction_x: float = 1.0 # 1.0 for right, -1.0 for left. Used for sprite flipping.
var can_attack: bool = true       # Flag to manage attack cooldown
var is_in_attack_animation: bool = false # Flag to track if player's attack animation is currently playing

var is_dodging: bool = false      # Flag for dodge state
var can_dodge: bool = true        # Flag for dodge cooldown

var current_health: int
var is_invincible: bool = false   # Flag for invincibility state
var is_knocked_back: bool = false # Flag for knockback state

# Collision layer constants (matching Project Settings -> Layer Names -> 2D Physics)
const PLAYER_LAYER = 1
const GROUND_LAYER = 2
const ENEMY_LAYER = 3
const PLAYER_ATTACK_LAYER = 4
const ENEMY_ATTACK_LAYER = 5 # If you use enemy projectiles/hitboxes

################################################################################
#                                  LIFECYCLE METHODS                            #
################################################################################

func _ready():
	# Connect the animation_finished signal to our handler function
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	
	# Initialize health
	current_health = MAX_HEALTH
	print("Player spawned. Health: ", current_health)

func _physics_process(delta: float):
	# --- Apply Gravity ---
	velocity.y += GRAVITY * delta

	# --- Handle Dodge Input ---
	# Dodge takes priority over all other movement/attack actions
	if Input.is_action_just_pressed("dodge") and can_dodge and not is_dodging and not is_knocked_back:
		perform_dodge()
		return # Skip all other input processing this frame if dodging

	# --- If not dodging, process other inputs ---
	if not is_dodging:
		# --- Handle Knockback ---
		if is_knocked_back:
			# During knockback, velocity is controlled by the knockback force.
			pass # Velocity is set in _start_knockback
		else: # Normal movement when not dodging or knocked back
			# --- Handle Horizontal Input ---
			var input_direction_x: float = Input.get_axis("left", "right")

			if input_direction_x != 0:
				velocity.x = lerp(velocity.x, input_direction_x * SPEED, ACCELERATION * delta)
				last_direction_x = input_direction_x
			else:
				velocity.x = lerp(velocity.x, 0.0, FRICTION * delta)
				if abs(velocity.x) < 5:
					velocity.x = 0.0

			# --- Coyote Time & Jump Buffer Timers ---
			if is_on_floor():
				coyote_timer = COYOTE_TIME
			else:
				coyote_timer -= delta

			if Input.is_action_just_pressed("jump"):
				jump_buffer_timer = JUMP_BUFFER_TIME
			else:
				jump_buffer_timer -= delta

			# --- Handle Jumping Logic ---
			if jump_buffer_timer > 0 and coyote_timer > 0:
				velocity.y = JUMP_VELOCITY
				coyote_timer = 0.0
				jump_buffer_timer = 0.0

			if Input.is_action_just_released("jump") and velocity.y < 0:
				velocity.y *= JUMP_CUT_MULTIPLIER

			# --- Handle Attack Input ---
			# Prioritize Down Attack: Triggered by (attack button pressed + down button held + not on floor)
			if Input.is_action_just_pressed("attack") and Input.is_action_pressed("down") \
			and not is_on_floor() and can_attack and not is_in_attack_animation:
				# Optional: velocity.y >= 0 ensures it's only allowed when falling or at jump apex.
				if velocity.y >= 0:
					perform_down_attack()
				else: # If pressing down+attack while jumping UP, treat as a normal horizontal attack
					perform_horizontal_attack()
			# Regular Horizontal Attack: Triggered by (attack button pressed, if not a down attack)
			elif Input.is_action_just_pressed("attack") and can_attack and not is_in_attack_animation:
				perform_horizontal_attack()
	else: # If currently dodging
		# During a dodge, player's horizontal velocity is fixed
		velocity.x = last_direction_x * DODGE_SPEED
		# Gravity still applies, so velocity.y continues to change normally.

	# --- Apply Movement using CharacterBody2D's built-in function ---
	move_and_slide()
	
	# It's good practice to set the up direction explicitly for move_and_slide()
	set_up_direction(Vector2.UP)

	# --- Update Animations based on current state ---
	update_animations()

################################################################################
#                                  ATTACK LOGIC                                 #
################################################################################

func perform_horizontal_attack():
	if not attack_sprite_scene:
		push_warning("Attack Sprite Scene not assigned in Player Inspector!")
		return

	can_attack = false
	is_in_attack_animation = true

	var attack_instance = attack_sprite_scene.instantiate()
	attack_instance.global_position = global_position + Vector2(last_direction_x * attack_offset_x, 0)
	
	if attack_instance.has_method("set_attack_direction"):
		attack_instance.set_attack_direction(last_direction_x)
	
	get_parent().add_child(attack_instance)
	attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "horizontal"))

	start_attack_cooldown()
	animated_sprite.play("attack")

func perform_down_attack():
	if not attack_sprite_scene:
		push_warning("Attack Sprite Scene not assigned in Player Inspector!")
		return
	
	can_attack = false
	is_in_attack_animation = true

	var attack_instance = attack_sprite_scene.instantiate()
	attack_instance.global_position = global_position + Vector2(0, down_attack_offset_y)
	
	if attack_instance.has_method("set_attack_direction"):
		attack_instance.set_attack_direction(last_direction_x) 

	get_parent().add_child(attack_instance)
	attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "down"))

	start_attack_cooldown()
	animated_sprite.play("down_attack")

func start_attack_cooldown():
	get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)

func _on_attack_effect_hit_enemy(enemy_node: Node, attack_type: String):
	if enemy_node and enemy_node.has_method("take_damage"):
		# Pass player's global_position for enemy knockback
		enemy_node.take_damage(attack_damage, global_position)
		
		if attack_type == "down":
			velocity.y = JUMP_VELOCITY * BOUNCE_VELOCITY_MULTIPLIER
			print("Player bounced off enemy from down attack!")


################################################################################
#                                  DODGE LOGIC                                  #
################################################################################

func perform_dodge():
	is_dodging = true
	can_dodge = false
	
	# Temporarily remove collision with ENEMY_LAYER for invulnerability
	set_collision_mask_value(ENEMY_LAYER, false)
	
	# Set dodge velocity immediately
	velocity.x = last_direction_x * DODGE_SPEED
	
	# Start sprite rotation Tween
	var tween = create_tween()
	tween.tween_property(animated_sprite, "rotation_degrees", animated_sprite.rotation_degrees + (DODGE_ROTATION_DEGREES * last_direction_x), DODGE_DURATION)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Start dodge duration timer
	get_tree().create_timer(DODGE_DURATION).timeout.connect(_end_dodge)

	animated_sprite.play("dodge") # Make sure you have a "dodge" animation and it's not looping!

func _end_dodge():
	is_dodging = false
	
	# Re-enable collision with ENEMY_LAYER
	set_collision_mask_value(ENEMY_LAYER, true)
	
	# Reset sprite rotation
	animated_sprite.rotation_degrees = 0 

	# Start dodge cooldown timer
	get_tree().create_timer(DODGE_COOLDOWN).timeout.connect(func(): can_dodge = true)
	
	# Re-evaluate animations now that dodge is over
	update_animations()

################################################################################
#                             DAMAGE / INVULNERABILITY LOGIC                    #
################################################################################

# Function called by external sources (e.g., enemies) when player takes damage
func take_damage(amount: int, source_position: Vector2):
	# Prevent taking damage if currently invincible or dodging
	if is_invincible or is_dodging:
		return

	current_health -= amount
	print("Player took ", amount, " damage. Current Health: ", current_health)

	if current_health <= 0:
		_die() # Call a death function
		return

	_start_invincibility()
	_start_knockback(source_position)

func _start_invincibility():
	is_invincible = true
	# Temporarily remove collision with ENEMY_LAYER for invulnerability
	set_collision_mask_value(ENEMY_LAYER, false)
	
	# Start flashing effect for visual invulnerability
	var tween = create_tween()
	tween.set_loops(int(INVINCIBILITY_DURATION * 12.5)) # Flash 12.5 times per second
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0.0), 0.04) # Fade out (fully transparent)
	tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1.0), 0.04) # Fade in (fully opaque)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	
	# After all flashes, ensure full opacity and end invincibility
	tween.finished.connect(_end_invincibility)


func _end_invincibility():
	is_invincible = false
	# Re-enable collision with ENEMY_LAYER
	set_collision_mask_value(ENEMY_LAYER, true)
	
	# Ensure sprite is fully opaque
	animated_sprite.modulate = Color(1, 1, 1, 1)

func _start_knockback(source_position: Vector2):
	is_knocked_back = true
	
	# Calculate knockback direction: from source to player
	var knockback_direction = (global_position - source_position).normalized()
	
	# Apply horizontal knockback
	velocity.x = knockback_direction.x * KNOCKBACK_FORCE_HORIZONTAL
	
	# Apply vertical knockback (upwards, regardless of horizontal direction)
	velocity.y = KNOCKBACK_FORCE_VERTICAL # This is a direct upward force

	# Start knockback duration timer
	get_tree().create_timer(KNOCKBACK_DURATION).timeout.connect(_end_knockback)

func _end_knockback():
	is_knocked_back = false
	# Velocity will naturally decay or be overridden by player input.
	
	# Update animations immediately to transition out of potential "hurt" or knocked-back state
	update_animations()

func _die():
	print("Player has been defeated!")
	# TODO: Implement death animation, reload scene, game over screen, etc.
	set_physics_process(false) # Stop player movement
	hide() # Hide player sprite
	# Or queue_free() the player node if that's how you handle death.


################################################################################
#                                  ANIMATION LOGIC                              #
################################################################################

func update_animations():
	if not animated_sprite: return # Safety check if node is not found

	# Handle sprite flipping first, as it applies to all states
	animated_sprite.flip_h = last_direction_x < 0

	# Prioritize Dodge animation if currently dodging
	if is_dodging:
		if animated_sprite.animation != "dodge" or not animated_sprite.is_playing():
			animated_sprite.play("dodge") # Ensure dodge anim is playing if we are in dodge state
		return # Do not change animation if dodging

	# Prioritize Attack animation if currently in an attack animation
	if is_in_attack_animation:
		# Check if the current animation being played by AnimatedSprite2D is indeed
		# an attack animation AND it's actually still playing frames.
		if (animated_sprite.animation == "attack" or animated_sprite.animation == "down_attack") \
		and animated_sprite.is_playing():
			return # Do not change animation if attack is still actively playing
		else:
			# If is_in_attack_animation is true, but the actual animation is not playing,
			# it means the animation finished, so we can reset the flag and proceed.
			is_in_attack_animation = false

	# Determine the target animation based on movement/grounded state
	var target_animation = ""
	if not is_on_floor():
		# Player is in the air
		if velocity.y < 0:
			target_animation = "jump" # Play jump animation while ascending
		else:
			target_animation = "fall" # Play fall animation while descending
	else:
		# Player is on the ground
		if abs(velocity.x) > 10: # Check if horizontal velocity is significant enough to be considered "walking"
			target_animation = "walk"
		else:
			target_animation = "idle"

	# Only change the animation if the determined target animation is different
	# from the animation currently playing.
	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

# This function is called automatically when any animation on animated_sprite finishes playing
func _on_animated_sprite_animation_finished():
	# If the animation that just finished was one of our attack animations,
	# it's time to allow other animations to play again.
	if animated_sprite.animation == "attack" or animated_sprite.animation == "down_attack":
		is_in_attack_animation = false # Reset the flag
		update_animations() # Re-evaluate to transition to idle/walk/jump/fall
	# Note: Dodge animation completion is handled by its own timer _end_dodge()
	# Invincibility visual flashing is handled by its own Tween.
