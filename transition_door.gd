# File: transition_door.gd
extends Area2D

## --- EXPORT VARIABLES ---
# Set these in the Inspector for each door you place in your levels.

## The scene file to load when the player enters.
@export_file("*.tscn") var target_scene_path: String

## The name of the Marker2D in the *new* scene where the player should appear.
@export var target_spawn_name: String


# This function is connected to the Area2D's "body_entered" signal.
func _on_body_entered(body):
	# First, check if the body that entered is the player.
	if body.is_in_group("player"):
		
		# --- CRITICAL STEP 1: SAVE PLAYER STATE ---
		# Before changing scenes, tell the player instance to save its current
		# data (like health) to the Global singleton.
		# The 'body' variable *is* the player node that just entered.
		if body.has_method("save_state"):
			body.save_state()
		else:
			printerr("TRANSITION ERROR: The player node is missing the save_state() method!")
			return # Stop if the player can't save, to prevent data loss.

		# --- CRITICAL STEP 2: CONFIGURE THE TRANSITION ---
		# Check if the door's properties are set in the Inspector.
		if target_scene_path.is_empty() or target_spawn_name.is_empty():
			printerr("TRANSITION ERROR: This door is not configured! Set its 'Target Scene Path' and 'Target Spawn Name' in the Inspector.")
			return

		# Tell the Global script where to spawn the player in the next scene.
		Global.player_spawn_name = target_spawn_name
		
		# --- CRITICAL STEP 3: CHANGE THE SCENE ---
		# Use call_deferred to safely change scenes after the physics step is over.
		print("Player state saved. Transitioning to scene: '", target_scene_path, "' at spawn point: '", target_spawn_name, "'")
		get_tree().call_deferred("change_scene_to_file", target_scene_path)
