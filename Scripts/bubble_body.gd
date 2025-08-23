class_name Bubble
extends RigidBody2D

@export var float_force: float = -40.0        # negative = up
@export var top_padding: float = 16.0         # world-space top (y=0) + padding
@export var life_after_top: float = 0.8
@onready var bubble_sprite: BubbleSprite = %BubbleSprite
@export var bubble_value: int = 1
@onready var bubble_sfx: AudioStreamPlayer = %BubbleSFX

# Sway/bobble tuning
@export var sway_force: float = 12.0          # left-right wiggle force
@export var sway_freq_hz: float = 0.8
@export var bobble_scale: float = 0.25    
@export var bobble_freq_hz: float = 1.2
@export var spin_deg_per_s: float = 20.0
@export var spin_freq_hz: float = 0.6

var _stuck := false
var _t := 0.0
var _phase_sway := 0.0
var _phase_bobble := 0.0
var _phase_spin := 0.0
var _popping := false  # guard so we only pop once

func _ready() -> void:
	input_event.connect(_on_pop_input)
	gravity_scale = 0.0
	can_sleep = false
	sleeping = false

	# Randomize phases so multiple bubbles don't sway in sync
	randomize()
	_phase_sway = randf() * TAU
	_phase_bobble = randf() * TAU
	_phase_spin = randf() * TAU

func _physics_process(delta: float) -> void:
	if _stuck:
		return

	_t += delta

	# forces (unchanged)
	var bobble := 1.0 + bobble_scale * sin(TAU * bobble_freq_hz * _t + _phase_bobble)
	var up_force := float_force * bobble
	var sway_x := sway_force * sin(TAU * sway_freq_hz * _t + _phase_sway)
	apply_central_force(Vector2(sway_x, up_force))

	var spin_rad_per_s := deg_to_rad(spin_deg_per_s)
	var torque := sin(TAU * spin_freq_hz * _t + _phase_spin) * spin_rad_per_s
	apply_torque(torque)

	# --- camera-aware top limit ---
	var top_limit := _top_visible_y() + top_padding
	if global_position.y <= top_limit:
		global_position.y = top_limit
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		freeze = true
		_stuck = true
		await get_tree().create_timer(life_after_top).timeout
		queue_free()

# Top edge of the *visible* screen in world coords (works with moving/zooming Camera2D)
func _top_visible_y() -> float:
	var world_from_screen: Transform2D = get_canvas_transform().affine_inverse()
	var top_left_world: Vector2 = world_from_screen * Vector2.ZERO
	return top_left_world.y

func _on_pop_input(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if _popping:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_do_pop()
		return

	if event is InputEventScreenTouch and event.pressed:
		_do_pop()
		return

func _do_pop() -> void:
	_popping = true
	bubble_sprite.play("Pop")
	bubble_sfx.play()
	Events.bubble_count_changed(bubble_value)
