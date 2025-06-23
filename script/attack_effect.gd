extends Area2D

# Signal emitted when this attack effect successfully hits an enemy.
# It passes the enemy Node that was hit.
signal hit_enemy(enemy_node: Node)

# Reference to the actual visual Sprite2D (or AnimatedSprite2D) child node.
# IMPORTANT: Make sure "$AttackVisual" matches the exact name of your visual sprite node!
@onready var visual_sprite: Sprite2D = $AttackVisual 
@onready var lifetime_timer: Timer = $LifetimeTimer

var already_hit = false

# These variables store the direction and type of attack passed by the player.
var pending_direction_x: float = 1.0  # Default facing right (1.0)
var pending_attack_type: String = "horizontal" # Default attack type

func _ready():
	# Connect the lifetime timer to remove this node when time runs out.
	lifetime_timer.timeout.connect(queue_free)
	
	# Connect the Area2D's body_entered signal to detect collisions.
	body_entered.connect(_on_body_entered)

	# Check if the visual sprite was found on scene ready.
	# If found, apply the initial direction/rotation immediately.
	if visual_sprite:
		apply_attack_direction() # Call immediately after setup
		print("✅ AttackEffect _ready: Visual sprite found, applied initial direction.") # DEBUG
	else:
		push_error("❌ AttackEffect _ready: visual_sprite node ('$AttackVisual') was NOT found!")


func _on_body_entered(body: Node):
	# Prevent hitting the same enemy (or any body) multiple times with one attack instance.
	if already_hit:
		return
		
	# Check if the collided body belongs to the "enemy" group.
	if body.is_in_group("enemy"):
		already_hit = true # Mark as already hit
		
		# Emit the signal to notify the player about the hit.
		emit_signal("hit_enemy", body)
		
		# Immediately remove the attack effect after it hits an enemy.
		queue_free()

# This function is called by the Player script to set the visual orientation of the attack.
func set_attack_direction(direction_x: float, attack_type: String = "horizontal"):
	# Store the values received from the player script.
	pending_direction_x = direction_x
	pending_attack_type = attack_type

	# Apply the changes immediately if the node is ready and visual_sprite is found.
	# The check 'is_inside_tree()' is good practice to ensure _ready() has finished.
	if is_inside_tree() and visual_sprite:
		apply_attack_direction()
	elif not visual_sprite:
		push_error("❌ AttackEffect set_attack_direction: visual_sprite node ('$AttackVisual') was NOT found when called!")


# This function applies the correct orientation purely through rotation.
# It assumes your base sprite graphic points to the right when rotation is 0.
func apply_attack_direction():
	if not visual_sprite:
		return

	# We will no longer use flip_h to avoid interference with rotation.
	# It's set to false to ensure a consistent base state before rotating.
	visual_sprite.flip_h = false

	var rotation_angle = 0.0
	match pending_attack_type:
		"horizontal":
			# If facing left, rotate 180 degrees. Otherwise, 0.
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
			
	# Apply the calculated rotation to the visual sprite.
	visual_sprite.rotation_degrees = rotation_angle
	print("AttackEffect: Final rotation set to ", rotation_angle) # DEBUG
