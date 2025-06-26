# File: Global.gd
extends Node

# --- TRANSITION DATA ---
var player_spawn_name: String = ""
var player_spawn_facing_direction: int = 1

# --- LEVEL DATA ---
var current_checkpoint_position: Vector2 = Vector2.ZERO

# --- PERSISTENT PLAYER DATA ---
var player_data = {
	"current_health": 100,
	"max_health": 100,
}

# Optional function to call from a main menu to start a fresh game.
func reset_player_data():
	player_data = {
		"current_health": 100,
		"max_health": 100,
	}
	current_checkpoint_position = Vector2.ZERO
