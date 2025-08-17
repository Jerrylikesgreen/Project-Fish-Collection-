class_name FishBody extends CharacterBody2D
# -- Tuning variables --
@export var speed: float = 60.0   
@export var change_direction_interval: float = 3.0  
@export var turn_smoothness: float = 5.0    

var direction: Vector2 = Vector2.RIGHT 
var target_direction: Vector2 = Vector2.RIGHT
var change_timer: float = 0.0

func _ready():
	randomize()
	_set_new_direction()

func _process(delta):
	change_timer -= delta
	if change_timer <= 0:
		_set_new_direction()

	direction = direction.lerp(target_direction, delta * turn_smoothness).normalized()

	position += direction * speed * delta

	# Clamp position to stay on screen
	var screen_size = get_viewport_rect().size
	var padding = -16  # adjust based on sprite size
	position.x = clamp(position.x, padding, screen_size.x - padding)
	position.y = clamp(position.y, padding, screen_size.y - padding)


	# Flip sprite if needed
	if has_node("Sprite2D"):
		$Sprite2D.flip_h = direction.x < 0


func _set_new_direction():
	target_direction = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()
	change_timer = randf_range(change_direction_interval * 0.5, change_direction_interval * 1.5)
