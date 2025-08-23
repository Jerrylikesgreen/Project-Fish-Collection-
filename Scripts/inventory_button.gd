class_name Collection_Button
extends Button




func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	Events._on_button_signal.emit()
