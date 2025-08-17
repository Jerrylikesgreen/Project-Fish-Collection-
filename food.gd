class_name food_button
extends Button

@onready var pop_up: PopUp = $"../../PopUp"

func _ready() -> void:
	pressed.connect(_on_button_pressed)
	pop_up.finished.connect(_on_popup_finished)  # Listen for when popup ends

func _on_button_pressed() -> void:
	disabled = true  # disable button
	Events.spawn_food_button_pressed()

func _on_popup_finished() -> void:
	disabled = false  # re-enable when done
