# File: SceneFader.gd
extends CanvasLayer

signal faded_to_black

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

func _ready():
	color_rect.color.a = 0.0

func fade_in():
	animation_player.play("fade_from_black")

func respawn_fade():
	# The player script's 'is_respawning' flag will handle pausing input.
	# We don't need to pause the whole tree here.
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	
	faded_to_black.emit()
	
	fade_in()

func change_scene_with_fade(scene_path: String):
	# We still pause here because we are destroying the old scene.
	get_tree().paused = true
	animation_player.play("fade_to_black")
	await animation_player.animation_finished
	
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		printerr("SceneFader Error: Could not load scene at path: ", scene_path)
		get_tree().paused = false
		return

	get_tree().paused = false
	fade_in()
