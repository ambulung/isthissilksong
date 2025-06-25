# File: SceneFader.gd
extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

# This function is called when the game first starts.
func _ready():
	# Make sure the screen is initially transparent.
	color_rect.color.a = 0.0

# Public function to fade the screen in (from black to transparent)
func fade_in():
	animation_player.play("fade_from_black")

# Public function that handles the entire transition process
func change_scene_with_fade(scene_path: String):
	# 1. Pause the game world.
	#    This freezes all physics, AI, projectiles, etc.
	get_tree().paused = true
	
	# 2. Play the fade-out animation.
	#    This node continues to work because its Process Mode is set to "Always".
	animation_player.play("fade_to_black")
	
	# 3. Wait for the fade-out animation to finish.
	await animation_player.animation_finished
	
	# 4. Now that the screen is black, change the scene.
	#    The game tree is still in the paused state at this point.
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		printerr("SceneFader Error: Could not load scene at path: ", scene_path)
		get_tree().paused = false # Unpause on error to prevent the game from getting stuck
		return

	# --- THE CRITICAL FIX ---
	# 5. Unpause the game tree immediately after the new scene has loaded.
	#    The game is now running, but the screen is still black.
	get_tree().paused = false
	
	# 6. Now, start the fade-in animation on the new, active scene.
	fade_in()
