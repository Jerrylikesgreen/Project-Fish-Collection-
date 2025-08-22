class_name FishPackMenu extends Panel

@onready var a_pack: APackButton = %APack
@onready var b_pack: BPackButton = %BPack
@onready var c_pack: CPackButton = %CPack


func _ready() -> void:
	Events.fish_pack_button_pressed.connect(_on_button_pressed)
	a_pack.pressed.connect(_on_a)
	b_pack.pressed.connect(_on_b)
	c_pack.pressed.connect(_on_c)
	
func _on_button_pressed()->void:
	if !visible:
		set_visible(true)
		
func _on_a()->void:
	Events.fish_pack_selected("A")
	set_visible(false)
	
func _on_b()->void:
	Events.fish_pack_selected("B")
	set_visible(false)
func _on_c()->void:
	Events.fish_pack_selected("C")
	set_visible(false)
