# File: Global.gd
extends Node

# --- TRANSITION DATA ---
# These are temporary variables used only during a scene change.

# Holds the name of the Marker2D in the next scene.
var player_spawn_name: String = ""

# Holds the direction the player should face. (1 = Right, -1 = Left)
var player_spawn_facing_direction: int = 1


# --- PERSISTENT PLAYER DATA ---
# This dictionary stores all the player's stats that carry over.
var player_data = {
	"current_health": 100,
	"max_health": 100,
	# Add other things to save here, like:
	# "money": 0,
	# "has_double_jump": false
}


# Optional function to call from a main menu to start a fresh game.
func reset_player_data():
	player_data = {
		"current_health": 100,
		"max_health": 100,
	}
