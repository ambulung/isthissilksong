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

################################################################################
#                                  NODES & STATE                                #
################################################################################

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var last_direction_x: float = 1.0 # 1.0 for right, -1.0 for left. Used for sprite flipping.
var can_attack: bool = true       # Flag to manage attack cooldown
var is_in_attack_animation: bool = false # Flag to track if player's attack animation is currently playing

################################################################################
#                                  LIFECYCLE METHODS                            #
################################################################################

func _ready():
	# Connect the animation_finished signal to our handler function
	# This will notify us when any animation (especially attack) finishes playing.
	animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)

func _physics_process(delta: float):
	# --- 1. Apply Gravity ---
	velocity.y += GRAVITY * delta

	# --- 2. Handle Horizontal Input ---
	var input_direction_x: float = Input.get_axis("left", "right") # Gets -1, 0, or 1

	if input_direction_x != 0:
		# Accelerate towards max speed using linear interpolation (lerp) for smooth feel
		velocity.x = lerp(velocity.x, input_direction_x * SPEED, ACCELERATION * delta)
		last_direction_x = input_direction_x # Update last direction for sprite flipping
	else:
		# Decelerate/Apply friction when no horizontal input
		velocity.x = lerp(velocity.x, 0.0, FRICTION * delta) 
		# Snap to zero to prevent tiny residual movement when almost stopped
		if abs(velocity.x) < 5: # Threshold (adjust if needed)
			velocity.x = 0.0 

	# --- 3. Coyote Time & Jump Buffer Timers ---
	if is_on_floor():
		coyote_timer = COYOTE_TIME # Reset coyote timer when grounded
	else:
		coyote_timer -= delta # Count down when in air

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME # Start jump buffer when jump is pressed
	else:
		jump_buffer_timer -= delta # Count down jump buffer

	# --- 4. Handle Jumping Logic ---
	if jump_buffer_timer > 0 and coyote_timer > 0:
		# If jump was pressed recently AND we are still in coyote time, perform a jump
		velocity.y = JUMP_VELOCITY
		coyote_timer = 0.0 # Consume coyote time after jumping
		jump_buffer_timer = 0.0 # Consume jump buffer after jumping

	# Variable Jump Height (Jump Cut)
	# If jump button is released while moving upwards, reduce vertical velocity
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	# --- 5. Handle Attack Input ---
	# Prioritize Down Attack: Triggered by (attack button pressed + down button held + not on floor)
	# Optional: velocity.y >= 0 ensures it's only allowed when falling or at jump apex.
	if Input.is_action_just_pressed("attack") and Input.is_action_pressed("down") \
	and not is_on_floor() and can_attack and not is_in_attack_animation:
		if velocity.y >= 0: # Only allow down attack if falling or at apex
			perform_down_attack()
		else: # If pressing down+attack while jumping UP, treat as a normal horizontal attack
			perform_horizontal_attack()
	# Regular Horizontal Attack: Triggered by (attack button pressed, if not a down attack)
	elif Input.is_action_just_pressed("attack") and can_attack and not is_in_attack_animation:
		perform_horizontal_attack()
	
	# --- 6. Apply Movement using CharacterBody2D's built-in function ---
	move_and_slide()
	
	# It's good practice to set the up direction explicitly for move_and_slide()
	set_up_direction(Vector2.UP)

	# --- 7. Update Animations based on current state ---
	update_animations()

################################################################################
#                                  ATTACK LOGIC                                 #
################################################################################

func perform_horizontal_attack():
	if not attack_sprite_scene:
		push_warning("Attack Sprite Scene not assigned in Player Inspector!")
		return

	can_attack = false # Disable attacking until cooldown is over
	is_in_attack_animation = true # Set flag that attack animation is now playing

	var attack_instance = attack_sprite_scene.instantiate()

	# Position in front of player
	attack_instance.global_position = global_position + Vector2(last_direction_x * attack_offset_x, 0)
	
	# Tell the attack instance which direction to face for its visual component
	if attack_instance.has_method("set_attack_direction"):
		attack_instance.set_attack_direction(last_direction_x)
	
	# Add the attack instance to the parent of the player node (e.g., the main level scene)
	get_parent().add_child(attack_instance)
	
	# Connect to the attack instance's hit_enemy signal for damage/bounce logic
	attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "horizontal"))

	start_attack_cooldown()
	animated_sprite.play("attack") # Play player's horizontal attack animation

func perform_down_attack():
	if not attack_sprite_scene:
		push_warning("Attack Sprite Scene not assigned in Player Inspector!")
		return
	
	can_attack = false
	is_in_attack_animation = true # Set flag that attack animation is now playing

	var attack_instance = attack_sprite_scene.instantiate()

	# Position below the player
	attack_instance.global_position = global_position + Vector2(0, down_attack_offset_y)
	
	# Tell the attack instance which direction to face for its visual component
	# For a down attack, you might still want it to flip if the visual is directional,
	# or pass 1.0 if it's always oriented the same way regardless of player facing.
	if attack_instance.has_method("set_attack_direction"):
		attack_instance.set_attack_direction(last_direction_x) 

	get_parent().add_child(attack_instance)
	
	# Connect to the attack instance's hit_enemy signal for damage/bounce logic
	attack_instance.hit_enemy.connect(func(enemy_node): _on_attack_effect_hit_enemy(enemy_node, "down"))

	start_attack_cooldown()
	animated_sprite.play("down_attack") # Play player's downward attack animation

func start_attack_cooldown():
	# Create a one-shot timer to reset can_attack flag after cooldown duration
	get_tree().create_timer(attack_cooldown).timeout.connect(func(): can_attack = true)

# Unified Attack Effect Hit Handler
func _on_attack_effect_hit_enemy(enemy_node: Node, attack_type: String):
	# Ensure the enemy node exists and has a 'take_damage' method
	if enemy_node and enemy_node.has_method("take_damage"):
		enemy_node.take_damage(attack_damage)
		
		# Apply Hollow Knight style bounce if it was a down attack
		if attack_type == "down":
			# Set player's Y velocity to an upward jump velocity, modified by bounce multiplier
			velocity.y = JUMP_VELOCITY * BOUNCE_VELOCITY_MULTIPLIER
			# You might want to add sound effects or particles here for the bounce.
			print("Player bounced off enemy from down attack!")
		
		# You could add different effects/logic for "horizontal" attack hits here too.


################################################################################
#                                  ANIMATION LOGIC                              #
################################################################################

func update_animations():
	if not animated_sprite: return # Safety check if node is not found

	# Flip player sprite based on the last recorded horizontal movement direction
	# This ensures the player faces the last direction they moved when idle
	animated_sprite.flip_h = last_direction_x < 0

	# If we are currently in an attack animation, prioritize it.
	# Check if the current animation is "attack" or "down_attack" AND it's still playing.
	# If the animation isn't playing but is_in_attack_animation is true,
	# it means the signal might be slightly delayed, so we allow it to proceed.
	if is_in_attack_animation:
		# Check if the current animation being played by AnimatedSprite2D is indeed
		# an attack animation AND it's actually still playing frames.
		# This prevents accidental early transitions if the animation somehow stopped
		# playing but the animation_finished signal hasn't fired yet.
		if animated_sprite.animation == "attack" and animated_sprite.is_playing() \
		or animated_sprite.animation == "down_attack" and animated_sprite.is_playing():
			return # Do not change animation if attack is still actively playing
		else:
			# If is_in_attack_animation is true, but the actual animation is not playing,
			# we can assume it finished and reset the flag here, then proceed to re-evaluate.
			# This can act as a fallback if the animation_finished signal is missed or delayed.
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
	# from the animation currently playing. This prevents constantly restarting animations.
	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)

# This function is called automatically when any animation on animated_sprite finishes playing
func _on_animated_sprite_animation_finished():
	# If the animation that just finished was one of our attack animations,
	# it's time to allow other animations to play again.
	if animated_sprite.animation == "attack" or animated_sprite.animation == "down_attack":
		is_in_attack_animation = false # Reset the flag
		# Immediately re-evaluate the animation state to transition to idle/walk/jump/fall
		update_animations() 
	# For other animations (like jump/fall if they're not looping),
	# update_animations() will naturally be called on the next physics frame
	# and handle transitions, so no explicit action needed here unless specific
	# post-animation logic is required.
