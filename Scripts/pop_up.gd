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

# ── Anti-spam controls ──────────────────────────────────────
@export var cooldown_seconds: float = 0.75    
@export var max_queue: int = 6            
@export var collapse_suffix: String = " (+{n} more)" 
# ────────────────────────────────────────────────────────────

var _queue: Array[String] = []
var _txt   := ""
var _idx   := 0
var _typing := false

var _next_allowed_time := 0.0       
var _dropped_overflow := 0          

func _ready() -> void:
	timer.timeout.connect(_on_timeout)
	timer.one_shot = true
	timer.wait_time = hold_seconds

	Events.player_message.connect(_on_player_message)

	visible = false
	set_text(" ")

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _on_player_message(msg: String) -> void:
	if _typing or not _queue.is_empty():
		_enqueue_or_collapse(msg)
		return

	var now := _now()
	if now < _next_allowed_time:
		_enqueue_or_collapse(msg)
		return

	_start(msg)
	_next_allowed_time = now + cooldown_seconds

func _enqueue_or_collapse(msg: String) -> void:
	if _queue.size() >= max_queue:
		_dropped_overflow += 1
	else:
		_queue.push_back(msg)

func _decorate_with_overflow(msg: String) -> String:
	if _dropped_overflow <= 0:
		return msg
	var s := collapse_suffix.replace("{n}", str(_dropped_overflow))
	_dropped_overflow = 0
	return msg + s

func _start(msg: String) -> void:
	_txt = _decorate_with_overflow(msg)
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
		var now := _now()
		if now < _next_allowed_time:
			var wait_more = max(_next_allowed_time - now, 0.0)
			await get_tree().create_timer(wait_more).timeout
		var next = _queue.pop_front()
		_start(next)
		_next_allowed_time = _now() + cooldown_seconds

func _grow_bubble() -> void:
	var need := get_minimum_size()
	need.x = max(need.x, min_width_pixels)
	need.y = max(need.y, min_height_pixels)
	panel.custom_minimum_size = need
