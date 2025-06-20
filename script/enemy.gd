extends CharacterBody2D

@export var MAX_HEALTH: int = 100
@export var enemy_damage: int = 10 # Damage this enemy deals to player

@export_group("Enemy Movement")
@export var chase_speed: float = 50.0 # Speed when chasing player
@export var patrol_speed: float = 20.0 # Speed when patrolling (if applicable)
@export var patrol_distance: float = 100.0 # Distance for simple patrol (if applicable)

@export_group("Enemy Damage & Invulnerability")
@export var INVINCIBILITY_DURATION_ENEMY: float = 0.5 # How long enemy is invulnerable after taking damage
@export var KNOCKBACK_FORCE_HORIZONTAL_ENEMY: float = 100.0 # Base horizontal force for enemy knockback
@export var KNOCKBACK_FORCE_VERTICAL_ENEMY: float = -80.0 # Base vertical force for enemy knockback (negative for upward)
@export var KNOCKBACK_DURATION_ENEMY: float = 0.15 # How long enemy knockback velocity is applied

# Enemy Weight for Knockback Resistance
@export var enemy_weight: float = 1.0 # 1.0 is default. Higher means less knockback, lower means more.

# Collision Layer Constants (make sure these match Project Settings)
const PLAYER_LAYER = 1
const GROUND_LAYER = 2
const ENEMY_LAYER = 3
const PLAYER_ATTACK_LAYER = 4
const ENEMY_ATTACK_LAYER = 5

# Enemy State Variables
var current_health: int
var is_invincible: bool = false
var is_knocked_back: bool = false
var is_player_detected: bool = false # Flag to track if player is in vision range

# References to child nodes
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # Assuming an AnimatedSprite2D child
@onready var vision_area: Area2D = $VisionArea # Reference to VisionArea (must be a child)
@onready var initial_position: Vector2 = global_position # For simple patrolling


func _ready():
	current_health = MAX_HEALTH
	
	# Connect signals from the VisionArea
	vision_area.body_entered.connect(_on_VisionArea_body_entered)
	vision_area.body_exited.connect(_on_VisionArea_body_exited)

func _physics_process(delta):
	# Apply Gravity
	velocity.y += 800 * delta 

	# --- Enemy Movement Logic ---
	if is_knocked_back:
		# During knockback, enemy's velocity is handled by the knockback function.
		# AI movement is paused during knockback.
		pass 
	elif is_player_detected:
		# Player is detected, chase them
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			var direction = (player_node.global_position - global_position).normalized()
			velocity.x = direction.x * chase_speed
			# Optional: Flip sprite based on chase direction
			if animated_sprite:
				animated_sprite.flip_h = direction.x < 0
		else:
			# Player node disappeared, stop chasing
			is_player_detected = false
			velocity.x = 0
	else:
		# Player not detected, simple patrol or idle
		if abs(global_position.x - initial_position.x) >= patrol_distance / 2:
			# Change direction if reached patrol limit
			velocity.x *= -1 # Reverse direction
			initial_position.x = global_position.x # Reset anchor for next patrol leg
		
		# Apply patrol speed if not already moving, or to ensure initial movement
		if velocity.x == 0 or abs(velocity.x) < patrol_speed: 
			velocity.x = sign(velocity.x) * patrol_speed # Maintain direction but enforce speed
		
		# Flip sprite for patrol direction
		if animated_sprite:
			animated_sprite.flip_h = velocity.x < 0

	# Apply movement and handle collisions
	move_and_slide()

	# --- Collision with Player for Dealing Damage to Player ---
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()

		if collider and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				# Call player's take_damage method, passing enemy's position as source for player knockback
				collider.take_damage(enemy_damage, global_position)
			break # Only damage player once per physics frame, even if multiple collisions


# --- MODIFIED: Enemy's take_damage function to trigger flash and knockback ---
# source_position is optional; if provided, knockback will be applied.
func take_damage(amount: int, source_position: Vector2 = Vector2.INF):
	if is_invincible:
		return

	current_health -= amount
	print("Enemy took ", amount, " damage. Health: ", current_health)

	if current_health <= 0:
		print("Enemy defeated!")
		queue_free() # Remove enemy node
		return

	# Trigger invincibility (which includes the flash effect)
	_start_invincibility()

	# Trigger knockback if a valid source_position was provided (i.e., not the default Vector2.INF)
	if source_position != Vector2.INF:
		_start_knockback(source_position)

# --- Enemy Invincibility Logic (Includes Flash) ---
func _start_invincibility():
	is_invincible = true
	# Temporarily remove collision with PlayerAttack layer for invincibility
	set_collision_mask_value(PLAYER_ATTACK_LAYER, false) 
	
	if animated_sprite:
		var tween = create_tween()
		# Loop the flash effect for the duration of invincibility
		tween.set_loops(int(INVINCIBILITY_DURATION_ENEMY * 12.5)) # Flash 12.5 times per second
		tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 0.0), 0.04) # Fade out (fully transparent)
		tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1, 1.0), 0.04) # Fade in (fully opaque)
		tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		# Connect to finished signal to ensure sprite is fully opaque and invincibility ends
		tween.finished.connect(_end_invincibility)
	else:
		# Fallback if no animated_sprite for visual feedback, just use a timer
		get_tree().create_timer(INVINCIBILITY_DURATION_ENEMY).timeout.connect(_end_invincibility)

func _end_invincibility():
	is_invincible = false
	# Re-enable collision with PlayerAttack layer
	set_collision_mask_value(PLAYER_ATTACK_LAYER, true)
	
	# Ensure sprite is fully opaque
	if animated_sprite:
		animated_sprite.modulate = Color(1, 1, 1, 1)

# --- MODIFIED: Enemy Knockback Logic (uses enemy_weight) ---
func _start_knockback(source_position: Vector2):
	is_knocked_back = true
	
	# Calculate knockback direction: away from the source
	var knockback_direction = (global_position - source_position).normalized()
	
	# Apply horizontal knockback velocity, inversely proportional to enemy_weight
	var calculated_horizontal_force = KNOCKBACK_FORCE_HORIZONTAL_ENEMY / max(0.1, enemy_weight)
	velocity.x = knockback_direction.x * calculated_horizontal_force
	
	# Apply vertical knockback velocity (upwards), also inversely proportional to weight
	var calculated_vertical_force = KNOCKBACK_FORCE_VERTICAL_ENEMY / max(0.1, enemy_weight)
	velocity.y = calculated_vertical_force 

	# Start a timer to end the knockback effect
	get_tree().create_timer(KNOCKBACK_DURATION_ENEMY).timeout.connect(_end_knockback)

func _end_knockback():
	is_knocked_back = false
	# Velocity will naturally decay or be overridden by next AI cycle.

# --- VisionArea Signal Handlers ---
func _on_VisionArea_body_entered(body: Node):
	if body.is_in_group("player"):
		is_player_detected = true
		print("Enemy: Player detected! Initiating chase.")

func _on_VisionArea_body_exited(body: Node):
	if body.is_in_group("player"):
		is_player_detected = false
		print("Enemy: Player left vision range. Returning to idle/patrol.")
		velocity.x = 0 # Stop chasing immediately
