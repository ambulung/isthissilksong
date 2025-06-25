# File: transition_door.gd
# This script is attached to a reusable Area2D scene for handling level transitions.
extends Area2D

## --- EXPORT VARIABLES ---
# These are configured in the Inspector for each door instance in your levels.

# The scene file to load when the player enters (e.g., "res://levels/level_2.tscn").
@export_file("*.tscn") var target_scene_path: String

# The name of the Marker2D in the *new* scene where the player should appear.
@export var target_spawn_name: String

# An easy-to-use dropdown in the Inspector to choose the player's spawn direction.
@export_enum("Left:-1", "Right:1") var target_facing_direction: int = 1


# This function is connected to the Area2D's "body_entered" signal.
# It runs when a PhysicsBody2D enters the door's collision shape.
func _on_body_entered(body):
	# 1. Check if the body that entered is the player.
	if body.is_in_group("player"):
		
		# 2. Tell the player to save its persistent data (like health) to the Global script.
		#    This check prevents errors if the method doesn't exist.
		if body.has_method("save_state"):
			body.save_state()
		else:
			printerr("TRANSITION ERROR: The player node is missing the save_state() method!")
			return # Stop to prevent data loss.

		# 3. Validate that this door has been configured in the Inspector.
		if target_scene_path.is_empty() or target_spawn_name.is_empty():
			printerr("TRANSITION ERROR: This door is not configured! Set 'Target Scene Path' and 'Target Spawn Name' in the Inspector.")
			return

		# 4. Pass the destination information to the Global script. This data will
		#    survive the scene change and be read by the next level's logic.
		Global.player_spawn_name = target_spawn_name
		Global.player_spawn_facing_direction = target_facing_direction
		
		print("Player state saved. Initiating fade transition to: '", target_scene_path, "'")

		# 5. Initiate the transition using our global SceneFader.
		#    The SceneFader will handle the fade-out, the scene change, and the fade-in.
		#    We no longer call get_tree().change_scene_to_file() directly from here.
		SceneFader.change_scene_with_fade(target_scene_path)
