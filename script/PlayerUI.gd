extends CanvasLayer

@export var health_icon_texture: Texture2D
@export var health_per_icon: int = 10

@export_group("Manual Layout")
@export var icon_start_position: Vector2 = Vector2(0, 0)
@export var icon_spacing: float = 30.0

# This path should point to the Node2D holder
@onready var health_icons_holder: Node2D = $HBoxContainer/HealthIconsHolder

func _ready() -> void:
	# Find the player in the scene tree.
	# We will add a print statement to be 100% sure this works.
	var player = get_tree().get_first_node_in_group("player")
	
	# If the player is found, connect to its signal and update the UI.
	if player:
		print("PlayerUI: Found the player successfully!")
		player.health_updated.connect(_on_player_health_updated)
		
		# Manually update the UI with the player's starting health.
		# This is the key to fixing the initialization.
		_on_player_health_updated(player.current_health, player.MAX_HEALTH)
	else:
		# If we get this message, the player is not in the "player" group.
		print("PlayerUI Error: Could not find the player node!")

func _on_player_health_updated(current_health: int, _max_health: int) -> void:
	# Clear out all the old health icons.
	for child in health_icons_holder.get_children():
		child.queue_free()
	
	# Calculate how many icons to show.
	var icons_to_show = int(current_health / float(health_per_icon))

	# Create and position each icon one by one.
	for i in range(icons_to_show):
		var icon = TextureRect.new()
		icon.texture = health_icon_texture
		
		# This is a critical check. If the texture is missing, we'll know why.
		if not icon.texture:
			print("PlayerUI Error: health_icon_texture is not assigned in the Inspector!")
			return

		# Calculate the position for this specific icon.
		var new_position = Vector2(icon_start_position.x + (i * icon_spacing), icon_start_position.y)
		
		# Set the icon's position.
		icon.position = new_position
		
		# Add the icon to our holder node.
		health_icons_holder.add_child(icon)
