class_name FishFood extends RigidBody2D

@export var drift_force: float = 5.0             # How strong the side-to-side drift is
@export var drift_frequency: float = 3.0         # How fast it wobbles

var drift_timer: float = 0.0

func _ready():
	gravity_scale = gravity_scale
	linear_damp = 1.0  # So it doesn't fall too fast or drift forever
	angular_damp = 1.0
	drift_timer = randf() * TAU

func _physics_process(delta):
	var force = Vector2(sin(drift_timer) * drift_force, 0)
	apply_central_force(force)

	# Optional: Remove if off-screen
	var screen_size = get_viewport_rect().size
	if global_position.y > screen_size.y + 50:
		queue_free()
		print("Free")
