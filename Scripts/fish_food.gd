class_name FishFood
extends RigidBody2D

@export var drift_force: float = 5.0
@export var drift_frequency: float = 3.0
@export var top_padding: float = 16.0
@export var gravity_scale_override: float = -0.05
@export var random_flip: bool = true
@export var launch_speed_left: float = 220.0   # px/s to the left during launch
@export var launch_duration: float = 0.20      # seconds of “shoot left”
@onready var fish_food_sprite: AnimatedSprite2D = %FishFoodSprite

var _rarity
var _launch_timer: float = 0.0
var _in_launch := true
var drift_timer: float = 0.0
var _locked_to_top := false

func _ready() -> void:
	randomize()
	gravity_scale = gravity_scale_override
	linear_damp = 1.0
	angular_damp = 1.0

	# start wobble at a random phase
	drift_timer = randf() * TAU
	if random_flip and (randi() & 1) == 1:
		drift_frequency *= -1.0

	# start launch phase
	_launch_timer = launch_duration
	_in_launch = _launch_timer > 0.0

func _physics_process(delta: float) -> void:
	# --- launch phase: force a quick push to the left, then hand off to wobble ---
	if _in_launch:
		_launch_timer -= delta
		# lock X velocity strongly left (ignores existing wobble for consistency)
		linear_velocity.x = -launch_speed_left
		linear_velocity.y = min(linear_velocity.y, 0.0)  # ensures food does not fall/float while launch. 

		if _launch_timer <= 0.0:
			_in_launch = false
	else:
		# normal horizontal wobble after launch
		drift_timer += delta * abs(drift_frequency)
		var push_x := sin(drift_timer) * drift_force * signf(drift_frequency)
		apply_central_force(Vector2(push_x, 0.0))

	# camera-aware “dock to top” behavior (works in both phases)
	var top_y := _top_visible_y() + top_padding
	if _locked_to_top:
		global_position.y = top_y
		linear_velocity.y = 0.0
	else:
		if global_position.y <= top_y:
			_locked_to_top = true
			gravity_scale = 0.0
			linear_velocity.y = 0.0
			global_position.y = top_y

func _top_visible_y() -> float:
	var world_from_screen: Transform2D = get_canvas_transform().affine_inverse()
	return (world_from_screen * Vector2.ZERO).y
