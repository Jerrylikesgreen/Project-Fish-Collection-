class_name Feed
extends Button

@onready var feeding: ColorRect = %Feeding

var _is_feed_mode: bool = false  # Track toggle state

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	feeding.visible = false  # Start hidden

func _on_button_pressed() -> void:
	_is_feed_mode = !_is_feed_mode  # Toggle state
	Events.spawn_food_mode.emit(_is_feed_mode)  # Emit the new mode state
	feeding.visible = _is_feed_mode  # Show/hide the indicator
	print("Feed mode toggled:", _is_feed_mode)
