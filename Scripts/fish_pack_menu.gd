class_name FishPackMenu
extends Panel

const FISH = preload("res://Scenes/fish.tscn")


var is_on := false
@onready var a_pack: Button = %APack
@onready var b_pack: Button = %BPack
@onready var c_pack: Button = %CPack
@onready var quit_button: Button = %QuitButton

var _dbg_id := "PACK_MENU"

func _ready() -> void:
	quit_button.pressed.connect(_on_pressed_x)
	if "fish_pack_button" in Events:
		Events.fish_pack_button_pressed.connect(_on_button_pressed)
		print("[%s] Connected to Events.fish_pack_button" % _dbg_id)
	elif "fish_pack_button_pressed" in Events:
		Events.fish_pack_button_pressed.connect(_on_button_pressed)
		print("[%s][WARN] Using legacy signal 'fish_pack_button_pressed' — consider renaming to 'fish_pack_button' for consistency." % _dbg_id)

	a_pack.pressed.connect(_on_a)
	b_pack.pressed.connect(_on_b)
	c_pack.pressed.connect(_on_c)
	print("[%s] Menu ready. Visible=%s" % [_dbg_id, str(visible)])

func _on_button_pressed() -> void:
	if !visible:
		print("[%s] Opening pack menu" % _dbg_id)
		visible = true

func _on_a() -> void:
	print("[%s] A pressed (no deduction here). Emitting selection 'A'." % _dbg_id)
	_emit_selection("A")
	visible = false

func _on_b() -> void:
	# Optional UI guard: show message, but DO NOT deduct
	if Globals.current_bubble_count < 10:
		Events.display_player_message("You need 10 Bubbles!")
		print("[%s] B pressed but low bubbles=%d (UI guard only). Still NOT deducting here." % [_dbg_id, Globals.current_bubble_count])
		return
	print("[%s] B pressed (no deduction here). Emitting selection 'B'." % _dbg_id)
	_emit_selection("B")
	visible = false

func _on_c() -> void:
	if Globals.current_bubble_count < 20:
		Events.display_player_message("You need 20 Bubbles! Keep Popping!")
		print("[%s] C pressed but low bubbles=%d (UI guard only). Still NOT deducting here." % [_dbg_id, Globals.current_bubble_count])
		return
	print("[%s] C pressed (no deduction here). Emitting selection 'C'." % _dbg_id)
	_emit_selection("C")
	visible = false

func _emit_selection(pack: String) -> void:
	# Unify on ONE selection signal name; your button listens to 'fish_pack_selected_signal'
	if "fish_pack_selected_signal" in Events:
		Events.fish_pack_selected_signal.emit(pack)
		print("[%s] Emitted fish_pack_selected_signal('%s')" % [_dbg_id, pack])
	elif "fish_pack_selected" in Events:
		Events.fish_pack_selected(pack)
		print("[%s][WARN] Emitted legacy fish_pack_selected('%s') — align names with the button." % [_dbg_id, pack])


func _on_pressed_x() -> void:
	visible = !visible
	
