class_name FishGacha extends Button



func _ready() -> void:
	pressed.connect(_on_pressed)
	
func _on_pressed()->void:
	if Globals.current_bubble_count > 5:
		Events.bubble_count_changed(-5)
		Events.spawn_fish()
	pass
