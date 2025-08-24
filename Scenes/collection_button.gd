class_name CollectionButton extends TextureButton


var _pressed: bool = false
func _ready() -> void:
	pressed.connect(_on_collections_button_pressed)


func _on_collections_button_pressed() -> void:
	_pressed = not _pressed
	print("[CollectionsButton] pressed ->", _pressed)
	Events.open_collections_screen.emit(_pressed)
	Events._on_button_signal.emit()
