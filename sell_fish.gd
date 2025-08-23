class_name SellFish extends Button

var _pressed: bool = false
func _ready() -> void:
	pressed.connect(_on_pressed)



func _on_pressed()->void:
	if _pressed:
		_pressed = false
		Events.sell_fish_button_pressed(_pressed)
	else:
		_pressed = true
		Events.sell_fish_button_pressed(_pressed)
	
	pass
