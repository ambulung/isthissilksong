# File: level_logic.gd
extends Node2D # Or Node, depending on your level's root node type.

# _ready() is called once when the level (and this node) is loaded into the game.
func _ready():
	# Check if the Global script has a spawn name for us.
	# If it's empty, it means we started the game in this level, so we do nothing.
	if not Global.player_spawn_name.is_empty():
		
		# Find the player node in the current scene. It must be in the "player" group.
		var player = get_tree().get_first_node_in_group("player")
		
		# Find the spawn marker node using the name from the Global script.
		var spawn_point = find_child(Global.player_spawn_name, true, false) # Search recursively
		
		# --- Error Checking ---
		if not player:
			printerr("LEVEL SCRIPT ERROR: Could not find node in group 'player'!")
		elif not spawn_point:
			printerr("LEVEL SCRIPT ERROR: Could not find spawn point named '", Global.player_spawn_name, "' in this level!")
		else:
			# --- If everything is good, move the player ---
			print("Spawning player at '", spawn_point.name, "'")
			player.global_position = spawn_point.global_position
		
		# --- CRITICAL STEP ---
		# Reset the global variable so it isn't used again by accident
		# (e.g., if the player dies and reloads the level).
		Global.player_spawn_name = ""
