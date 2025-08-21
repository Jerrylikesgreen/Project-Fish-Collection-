class_name FishSensor
extends Area2D

@export var refresh_rate: float = 0.2   # seconds between retarget checks

signal target_acquired(target: Node2D)
signal target_lost(previous: Node2D)
signal target_changed(new_target: Node2D, previous: Node2D)

var _current: Node2D = null
var _foods: Array[Node2D] = []
var _timer := Timer.new()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# NOTE: no body_exited hookup

	_timer.wait_time = refresh_rate
	_timer.one_shot = false
	_timer.timeout.connect(_retarget)
	add_child(_timer)
	_timer.start()

func get_target() -> Node2D:
	return _current

func _on_body_entered(b: Node2D) -> void:
	if not is_instance_valid(b): return
	if _foods.has(b): return
	_foods.append(b)

# Called by the fish when it actually eats a piece of food
func consume_food(node: Node) -> void:
	var idx := _foods.find(node)
	if idx != -1:
		_foods.remove_at(idx)
	if node == _current:
		_set_target(null)  # release current so we can retarget

func _retarget() -> void:
	# If no food in array, check inside area (your requirement)
	if _foods.is_empty():
		for bodies in get_overlapping_bodies():
			if not _foods.has(bodies):
				_foods.append(bodies)

	# Prune dead/freed nodes (in case something got deleted)
	_foods = _foods.filter(func(f):
		return is_instance_valid(f) and f is Node2D and f.is_inside_tree()
	)

	if _foods.is_empty():
		_set_target(null)
		return

	# Pick nearest
	var best: Node2D = null
	var best_d2 := INF
	for f in _foods:
		var d2 := global_position.distance_squared_to(f.global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = f

	_set_target(best)

func _set_target(t: Node2D) -> void:
	if t == _current:
		return
	var prev := _current
	_current = t
	if _current and not prev:
		target_acquired.emit(_current)
	elif not _current and prev:
		target_lost.emit(prev)
	else:
		target_changed.emit(_current, prev)
