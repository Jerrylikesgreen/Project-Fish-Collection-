class_name UpgradeButton extends TextureButton




func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed()->void:
	Events.upgrade_button_pressed()
