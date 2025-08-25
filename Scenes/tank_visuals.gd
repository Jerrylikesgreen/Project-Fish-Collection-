class_name TankVisuals
extends TextureRect

@export var tank_sprites: Array[CompressedTexture2D]
var current_tank: int = 0   # start at 0

func _ready() -> void:
	Events.update_ui.connect(_on_upgrade)

func _on_upgrade() -> void:
	print("Upgrades received")

	current_tank += 1
	_apply_sprite()

func _apply_sprite() -> void:
	texture = tank_sprites[current_tank]
	print(current_tank, texture)
