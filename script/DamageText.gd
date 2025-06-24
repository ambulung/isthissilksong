extends Node2D

@export var bounce_height: float = -40.0 # How high the text bounces (negative is up)
@export var bounce_duration: float = 0.6  # Total time for the bounce animation
@export var fade_out_delay: float = 0.2 # When the fade-out starts during the bounce
@export var horizontal_drift: float = 20.0 # How far it can drift left or right

@onready var label: Label = $Label

# This is the main function we'll call to start the effect.
func show_damage(damage_amount: int):
	# Set the text on the label
	label.text = str(damage_amount)
	
	# Create a tween to handle all the animation
	var tween = create_tween()
	
	# The tween will delete the node when all animations are finished
	tween.finished.connect(queue_free)

	# --- Bounce Animation ---
	# Move the text up to its peak height, slowing down as it reaches the top.
	var bounce_peak_position = position + Vector2(0, bounce_height)
	tween.tween_property(self, "position", bounce_peak_position, bounce_duration * 0.4)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# Move the text back down, speeding up as it falls.
	var bounce_end_position = position + Vector2(0, bounce_height * -0.5) # Fall a bit lower
	tween.parallel().tween_property(self, "position", bounce_end_position, bounce_duration * 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# --- Horizontal Drift Animation ---
	var drift_amount = randf_range(-horizontal_drift, horizontal_drift)
	var drift_position = position + Vector2(drift_amount, 0)
	tween.parallel().tween_property(self, "position:x", drift_position.x, bounce_duration)

	# --- Fade Out Animation ---
	# Make the label fully transparent over time.
	tween.parallel().tween_property(label, "modulate:a", 0.0, bounce_duration - fade_out_delay)\
		.set_delay(fade_out_delay)
