class_name FishFood
extends RigidBody2D

# --- Tuning ---
@export var drift_force: float = 5.0                 # horizontal wobble strength (as velocity target)
@export var drift_frequency: float = 3.0             # wobble frequency; sign controls direction
@export var top_padding: float = 16.0                # how far below the top of the screen to "dock"
@export var gravity_scale_override: float = -0.05    # floating upward until dock
@export var random_flip: bool = true                 # randomize wobble direction on spawn

# Launch burst to the left before wobble takes over
@export var launch_speed_left: float = 220.0         # px/s
@export var launch_duration: float = 0.20            # seconds
@export var use_impulse_launch: bool = false         # true = set once; false = force each tick during launch

# Docking / jitter controls
@export var use_custom_integrator_lock: bool = true  # robust “no jitter” mode when docked
@export var re_align_threshold_px: float = 0.5       # how much top must move before re-snap

# Optional sprite reference (not required for physics)
@onready var fish_food_sprite: AnimatedSprite2D = %FishFoodSprite

# --- State ---
var _rarity
var _launch_timer: float = 0.0
var _in_launch: bool = true
var _launch_impulsed: bool = false

var _locked_to_top: bool = false
var _dock_y: float = 0.0

var _phase: float = 0.0    # wobble phase accumulator

func _ready() -> void:
	# Base physics setup
	gravity_scale = gravity_scale_override
	linear_damp = 1.0
	angular_damp = 1.0

	# Start wobble at a random phase and direction
	_phase = randf() * TAU
	if random_flip and (randi() & 1) == 1:
		drift_frequency *= -1.0

	# Launch phase
	_launch_timer = launch_duration
	_in_launch = _launch_timer > 0.0

	print("[Food] ready: g=%.3f launch=%.3fs freq=%.3f" % [gravity_scale, _launch_timer, drift_frequency])

func _physics_process(delta: float) -> void:
	# --- LAUNCH ---
	if _in_launch:
		_launch_timer -= delta
		if use_impulse_launch:
			if not _launch_impulsed:
				linear_velocity = Vector2(-launch_speed_left, min(linear_velocity.y, 0.0))
				_launch_impulsed = true
				print("[Food] launch impulse v=", linear_velocity)
		else:
			linear_velocity.x = -launch_speed_left
			linear_velocity.y = min(linear_velocity.y, 0.0)

		if _launch_timer <= 0.0:
			_in_launch = false
			_launch_impulsed = false
			print("[Food] launch end v=", linear_velocity)
	else:
		# --- WOBBLE (horizontal) ---
		_phase += delta * absf(drift_frequency)
		var target_vx := sin(_phase) * drift_force * signf(drift_frequency)
		linear_velocity.x = lerp(linear_velocity.x, target_vx, clamp(8.0 * delta, 0.0, 1.0))

	# --- DOCK TO TOP ---
	var top_y := _get_top_y() + top_padding

	if _locked_to_top:
		# If using custom integrator, _integrate_forces pins Y; otherwise steady it here.
		if not use_custom_integrator_lock:
			linear_velocity.y = 0.0
			if absf(global_position.y - top_y) > re_align_threshold_px:
				global_position.y = top_y
				print("[Food] re-align (no integrator) y=%.2f" % global_position.y)
	else:
		if global_position.y <= top_y:
			_locked_to_top = true
			_dock_y = top_y
			gravity_scale = 0.0
			linear_velocity.y = 0.0
			global_position.y = _dock_y # snap once
			print("[Food] docked @ y=%.2f" % _dock_y)

			if use_custom_integrator_lock:
				custom_integrator = true   # we’ll control motion while docked

# Runs only when custom_integrator == true
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not _locked_to_top or not use_custom_integrator_lock:
		custom_integrator = false
		return

	# Horizontal wobble under our control (no forces = no jitter)
	_phase += state.step * absf(drift_frequency)
	var target_vx := sin(_phase) * drift_force * signf(drift_frequency)

	var lv := state.linear_velocity
	lv.x = lerp(lv.x, target_vx, clamp(8.0 * state.step, 0.0, 1.0))
	lv.y = 0.0
	state.linear_velocity = lv

	# Update dock Y to follow camera top smoothly (only if it moved enough)
	var desired_y := _get_top_y() + top_padding
	if absf(_dock_y - desired_y) > re_align_threshold_px:
		_dock_y = desired_y
		print("[Food] re-align (integrator) y=%.2f" % _dock_y)

	var xf := state.transform
	xf.origin.y = _dock_y
	state.transform = xf

func _get_top_y() -> float:
	# Top of the visible canvas in world coords; slight snapping reduces sub-pixel thrash
	var world_from_screen: Transform2D = get_canvas_transform().affine_inverse()
	var y := (world_from_screen * Vector2.ZERO).y
	return floorf(y * 2.0) / 2.0
