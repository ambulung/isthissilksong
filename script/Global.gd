# File: Global.gd
extends Node

# This holds the spawn point for the next scene
var player_spawn_name: String = ""

# This dictionary will store all persistent player data.
# It's much cleaner than having dozens of individual variables here.
var player_data = {
	"current_health": 100,
	"max_health": 100,
	"has_grapple": true, # Example for an upgrade
	"money": 0
}

# Optional: A function to reset player data for a new game.
# You could call this from your main menu.
func reset_player_data():
	player_data = {
		"current_health": 100,
		"max_health": 100,
		"has_grapple": true,
		"money": 0
	}
