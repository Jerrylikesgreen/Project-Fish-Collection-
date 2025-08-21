class_name Feed
extends Button


var _is_feed_mode: bool = false  # Track toggle state

func _ready() -> void:
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	_is_feed_mode = !_is_feed_mode  # Toggle state
	Events.food_gatcha_signal
