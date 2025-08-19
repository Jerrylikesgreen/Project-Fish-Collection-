extends Button

@onready var menu: Panel = %Menu
var _visible: bool = true


func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	print("Bloop")
	menu.visible = not menu.visible
