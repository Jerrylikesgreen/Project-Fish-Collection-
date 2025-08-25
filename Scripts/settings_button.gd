class_name SettingButton extends TextureButton



var _pressed: bool = false
func _ready() -> void:
	pressed.connect(_on_setting_button_pressed)


func _on_setting_button_pressed() -> void:
	_pressed = not _pressed
	print("[SettingsButton] pressed ->", _pressed)
	Events.setting_button_pressed_signal.emit(_pressed)
	Events._on_button_signal.emit()
