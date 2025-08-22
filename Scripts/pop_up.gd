class_name PopUp
extends Label

signal finished

# ── Node refs ───────────────────────────────────────────────
@onready var food  : Button          = %Food                
@onready var timer : Timer           = %Timer
@onready var panel : PanelContainer  = %PanelContainer
# ────────────────────────────────────────────────────────────

@export var speed: float = 0.08            
@export var min_width_pixels  := 120
@export var min_height_pixels := 32
@export var hold_seconds: float = 1.0      

var _queue: Array[String] = []
var _txt   := ""
var _idx   := 0
var _typing := false

func _ready() -> void:
	timer.timeout.connect(_on_timeout)
	timer.one_shot = true
	timer.wait_time = hold_seconds

	if is_instance_valid(food):
		food.pressed.connect(_on_button_pressed)

	Events.player_message.connect(_on_player_message)

	visible = false
	set_text(" ") 

func _on_button_pressed() -> void:
	_on_player_message("Fish Food!")

func _on_player_message(msg: String) -> void:
	if _typing:
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
	timer.start()

func _type() -> void:
	while _idx < _txt.length():
		text += _txt[_idx]
		_idx += 1
		_grow_bubble()
		await get_tree().create_timer(speed).timeout


func _on_timeout() -> void:
	if _queue.is_empty():
		visible = false
		finished.emit()
	else:
		_start(_queue.pop_front())


func _grow_bubble() -> void:
	var need := get_minimum_size()
	need.x = max(need.x, min_width_pixels)
	need.y = max(need.y, min_height_pixels)
	panel.custom_minimum_size = need
