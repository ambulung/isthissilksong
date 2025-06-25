# File: level_logic.gd
# This script should be attached to the root node of every level scene.
# Its job is to correctly position the player and camera when a scene loads via a transition.
extends Node2D # Or Node, or whatever your level's root node type is.


# The _ready() function is called when this node (and the level) enters the scene tree.
func _ready():
	# Wait for one full processing frame before running any logic.
	# This is a robust way to guarantee that all other nodes in the scene (like the Player)
	# have also run their own _ready() functions and are fully initialized.
	await get_tree().process_frame

	# Check if we have spawn instructions from the Global script. If the spawn name is empty,
	# it means we are not coming from a transition door, so we do nothing.
	if not Global.player_spawn_name.is_empty():
		
		# --- GATHER REQUIRED NODES ---
		var player = get_tree().get_first_node_in_group("player")
		var spawn_point = find_child(Global.player_spawn_name, true, false) # Search recursively
		var camera = get_tree().get_first_node_in_group("camera") as Camera2D
		
		
		# --- VALIDATE AND EXECUTE SPAWN LOGIC ---
		# First, check if we successfully found all the nodes we need.
		if not player:
			printerr("LEVEL SCRIPT ERROR: Could not find node in group 'player' in this scene!")
		elif not spawn_point:
			printerr("LEVEL SCRIPT ERROR: Could not find spawn point named '", Global.player_spawn_name, "' in this scene! Check for typos.")
		else:
			# If everything is valid, perform the spawn actions. This all happens while
			# the screen is still black from the SceneFader.
			
			# 1. Instantly move the player to the spawn point's position.
			player.global_position = spawn_point.global_position
			
			# 2. Tell the player which direction to face.
			if player.has_method("set_facing_direction"):
				player.set_facing_direction(Global.player_spawn_facing_direction)
			
			# 3. Instantly snap the camera to the player's new position.
			#    This prevents the camera from "panning" to the player when the scene fades in.
			if camera:
				camera.reset_smoothing()
			else:
				# This warning is helpful if you forget to add a camera to a level.
				push_warning("LEVEL SCRIPT WARNING: No camera node found in group 'camera'. Cannot reset smoothing.")
			
			print("Spawn successful: Player moved to '", spawn_point.name, "' and camera snapped.")
		
		
		# --- CRITICAL CLEANUP STEP ---
		# Reset the global transition variables to their default state.
		# This is essential to prevent this logic from re-running incorrectly if the
		# player dies and the scene is reloaded.
		Global.player_spawn_name = ""
		Global.player_spawn_facing_direction = 1 # Reset to default (Right)
