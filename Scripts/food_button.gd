class_name food_button
extends Button

@export var food_cost: int
@onready var pop_up: PopUp = %PopUp

func _ready() -> void:
	food_cost = Globals.food_cost
	pressed.connect(_on_button_pressed)
	pop_up.finished.connect(_on_popup_finished)  # Listen for when popup ends

func _on_button_pressed() -> void:
	if Globals.current_bubble_count < food_cost:
		return
	disabled = true  # disable button
	Events.spawn_food_button_pressed()

func _on_popup_finished() -> void:
	disabled = false  # re-enable when done
