class_name Debug extends Label



func _ready() -> void:
	Events.food_gatcha.connect(_on_food_mode)
	

func _on_food_mode(food_mode)->void:
	set_text("Food Mode: " + str(food_mode))
