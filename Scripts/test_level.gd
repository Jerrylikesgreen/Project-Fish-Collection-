extends Node2D

func _ready() -> void:
	# Use the wrapper so it logs and announces once.
	Events.game_start()
