class_name PopUp
extends Label

signal finished

# ── Node refs ───────────────────────────────────────────────
@onready var food  : Button          = %Food                 # if it's a Button; change type if you have a custom class
@onready var timer : Timer           = %Timer
@onready var panel : PanelContainer  = %PanelContainer
# ────────────────────────────────────────────────────────────

@export var speed: float = 0.08                 # seconds per character
@export var min_width_pixels  := 120
@export var min_height_pixels := 32
@export var hold_seconds: float = 1.0         # how long to keep the bubble visible after typing

var _queue: Array[String] = []
var _txt   := ""
var _idx   := 0
var _typing := false

func _ready() -> void:
	# Wire signals
	timer.timeout.connect(_on_timeout)
	timer.one_shot = true
	timer.wait_time = hold_seconds

	if is_instance_valid(food):
		food.pressed.connect(_on_button_pressed)

	# Connect to your global signal: it must be `signal player_message(msg: String)`
	# (If your signal carries different args, adjust the callback signature.)
	Events.player_message.connect(_on_player_message)

	# start hidden & cleared
	visible = false
	set_text(" ") 

func _on_button_pressed() -> void:
	# manual test: clicking the Food button will show a popup
	_on_player_message("You got a food.")

func _on_player_message(msg: String) -> void:
	if _typing:
		# queue in natural order
		_queue.push_back(msg)
	else:
		_start(msg)

func _start(msg: String) -> void:
	_txt = msg
	_idx = 0
	_typing = true
	set_text("")
	visible = true
	await _type()
	_typing = false
	timer.start() # will hide after hold_seconds

func _type() -> void:
	while _idx < _txt.length():
		text += _txt[_idx]  # Append instead of overwrite
		_idx += 1
		_grow_bubble()
		await get_tree().create_timer(speed).timeout


func _on_timeout() -> void:
	if _queue.is_empty():
		visible = false
		finished.emit()  # signal done
	else:
		_start(_queue.pop_front())

# ─────────────────────────────────────────────
# Resize helper – sizes the bubble to the text
# ─────────────────────────────────────────────
func _grow_bubble() -> void:
	var need := get_minimum_size()
	need.x = max(need.x, min_width_pixels)
	need.y = max(need.y, min_height_pixels)
	panel.custom_minimum_size = need
