class_name SettingMenu extends Panel


@onready var setting_exit: TextureButton = %SettingExit



func _ready() -> void:
	setting_exit.pressed.connect(_on_button_received)
	Events.setting_button_pressed_signal.connect(_on_signal_received)
	
func _on_signal_received(enabled:bool) -> void:
	if visible:
		set_visible(false)
		print(false)
		
	else:
		visible = not visible
		print("[Collection] toggle self -> %s" % str(visible))
		
func _on_button_received() -> void:
	Events._on_button_signal.emit()
	if visible:
		set_visible(false)
		print(false)
		
	else:
		visible = not visible
		print("[Collection] toggle self -> %s" % str(visible))
