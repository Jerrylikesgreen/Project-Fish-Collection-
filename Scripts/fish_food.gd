class_name FishFood
extends RigidBody2D

@export var drift_force: float = 5.0
@export var drift_frequency: float = 3.0
@export var top_padding: float = 16.0          # pixels below top of *visible* screen
@export var gravity_scale_override: float = -0.05  # slight upward pull until it docks
@export var random_flip: bool = true

var drift_timer: float = 0.0
var _locked_to_top := false

func _ready() -> void:
	randomize()
	gravity_scale = gravity_scale_override
	linear_damp = 1.0
	angular_damp = 1.0
	drift_timer = randf() * TAU
	if random_flip and (randi() & 1) == 1:
		drift_frequency *= -1.0  # mirror the sine

func _physics_process(delta: float) -> void:
	# horizontal wobble (works docked or not)
	drift_timer += delta * abs(drift_frequency)
	var push_x := sin(drift_timer) * drift_force * signf(drift_frequency)
	apply_central_force(Vector2(push_x, 0.0))

	# camera-aware top
	var top_y := _top_visible_y() + top_padding

	if _locked_to_top:
		# keep riding the top edge as camera moves
		global_position.y = top_y
		linear_velocity.y = 0.0
	else:
		# dock when we reach/cross the top
		if global_position.y <= top_y:
			_locked_to_top = true
			gravity_scale = 0.0          # stop vertical acceleration
			linear_velocity.y = 0.0      # kill vertical motion
			global_position.y = top_y    # snap to exact line

func _top_visible_y() -> float:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var world_from_screen: Transform2D = get_canvas_transform().affine_inverse()
	return (world_from_screen * Vector2.ZERO).y
