extends Button
@onready var photo_hud: Control = %PhotoHUD

func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed()->void:
	print("toogle")
	photo_hud.toggle()
