class_name Feed
extends Button


var _pressed := false

func _ready() -> void:

	_pressed = Events.selling_fish
	Events.sell_fish_button_pressed(_pressed)

func _on_pressed() -> void:
	_pressed = !_pressed
	Events.sell_fish_button_pressed(_pressed)
