class_name completed extends Panel

@onready var button: Button = $Button


func _ready() -> void:
	Events.collection_completed.connect(_on_completed)
	button.pressed.connect(_on_pressed)



func _on_completed()->void:
	visible = true

func _on_pressed()->void:
	visible = false 
