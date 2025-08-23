extends Node2D



func _ready() -> void:
	Events.game_started.emit()
	Events.display_player_message("Pop 5 Bubbles for a Fish Gacha!")
	Events.display_player_message("If your fish is sad, You need to feed it!")
