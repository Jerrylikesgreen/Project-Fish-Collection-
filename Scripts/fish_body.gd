class_name FishBody
extends CharacterBody2D

# ── Movement / Wander ───────────────────────────────────────
@export var speed: float = 60.0
@export var change_direction_interval: float = 3.0     # seconds between random headings
@export var turn_smoothness: float = 5.0               # higher = slower to turn (more smoothing)

# ── Edge Handling ───────────────────────────────────────────
@export var padding: float = 20.0                      # keep this far from screen edges
@export var body_radius: float = 12.0                  # half-size of the sprite/body to avoid clipping
@export var avoid_distance: float = 120.0              # start steering away when within this distance
@export var avoid_strength: float = 3.0                # how hard to steer away from edges
@export var center_pull: float = 0.8                   # mild bias toward view center while evading
@export var corner_boost: float = 1.5                  # extra push when near two edges (a corner)
@export var evade_turn_multiplier: float = 3.0         # turn faster while evading
@export var min_evade_pause: float = 0.3               # pause wander retargeting while evading (sec)
@export var jitter_strength: float = 0.05              # tiny randomness to avoid perfect orbits

# ── Visuals ────────────────────────────────────────────────
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# ── State ──────────────────────────────────────────────────
var direction: Vector2 = Vector2.RIGHT
var target_direction: Vector2 = Vector2.RIGHT
var change_timer: float = 0.0

func _ready() -> void:
	randomize()
	_set_new_direction()

func _physics_process(delta: float) -> void:
	# Count down until next wander retarget
	change_timer -= delta

	# Apply edge-avoid steering; returns true if near edges
	var evading := _apply_edge_avoidance(delta)

	# Only pick a new random heading if we’re NOT evading
	if change_timer <= 0.0 and not evading:
		_set_new_direction()

	# Turn faster when evading
	var turn := turn_smoothness * (evade_turn_multiplier if evading else 1.0)
	target_direction = target_direction.normalized()
	direction = direction.lerp(target_direction, delta * turn).normalized()

	# Move
	velocity = direction * speed
	move_and_slide()

	# Safety net: clamp & reflect if we somehow touched the bounds
	_reflect_if_clamped()

	# Face movement direction
	if direction.length() > 0.001:
		sprite.rotation = direction.angle()

# Calculate safe rect in WORLD space (camera-aware)
func _get_safe_rect() -> Rect2:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var world_from_screen: Transform2D = get_canvas_transform().affine_inverse()
	var tl: Vector2 = world_from_screen * Vector2.ZERO
	var br: Vector2 = world_from_screen * vp_size

	var min_x := tl.x + padding + body_radius
	var max_x := br.x - padding - body_radius
	var min_y := tl.y + padding + body_radius
	var max_y := br.y - padding - body_radius

	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

# Soft steering away from edges; adjusts target_direction and returns whether we’re near edges
func _apply_edge_avoidance(delta: float) -> bool:
	var r := _get_safe_rect()
	var min_x := r.position.x
	var min_y := r.position.y
	var max_x := r.position.x + r.size.x
	var max_y := r.position.y + r.size.y

	var p := global_position
	var center := Vector2(min_x + max_x, min_y + max_y) * 0.5

	# Distances to each boundary (positive inside)
	var d_left  := p.x - min_x
	var d_right := max_x - p.x
	var d_top   := p.y - min_y
	var d_bot   := max_y - p.y

	var steer := Vector2.ZERO

	# Ramp weights 0..1 as we approach each wall
	var wl = clamp((avoid_distance - d_left)  / avoid_distance, 0.0, 1.0)
	var wr = clamp((avoid_distance - d_right) / avoid_distance, 0.0, 1.0)
	var wt = clamp((avoid_distance - d_top)   / avoid_distance, 0.0, 1.0)
	var wb = clamp((avoid_distance - d_bot)   / avoid_distance, 0.0, 1.0)

	# Accumulate push away from walls (left -> +x, right -> -x, top -> +y, bottom -> -y)
	if d_left  < avoid_distance:  steer.x +=  wl
	if d_right < avoid_distance:  steer.x += -wr
	if d_top   < avoid_distance:  steer.y +=  wt
	if d_bot   < avoid_distance:  steer.y += -wb

	var near := steer != Vector2.ZERO
	if near:
		# Corner boost if near two or more edges
		var near_count := int(d_left < avoid_distance) + int(d_right < avoid_distance) + int(d_top < avoid_distance) + int(d_bot < avoid_distance)
		var boost := (corner_boost if near_count >= 2 else 1.0)

		# Blend steer-away with a mild pull toward center
		var to_center := (center - p).normalized()
		var blended := (steer.normalized() * avoid_strength * boost + to_center * center_pull).normalized()

		# Lock target more decisively away from the wall and add a tiny jitter
		target_direction = (blended + Vector2(randf() - 0.5, randf() - 0.5) * jitter_strength).normalized()

		# Pause wander retargeting briefly so it doesn't fight avoidance
		change_timer = max(change_timer, min_evade_pause)

	return near

# Last-resort clamp and bounce off edges
func _reflect_if_clamped() -> void:
	var r := _get_safe_rect()
	var min_x := r.position.x
	var min_y := r.position.y
	var max_x := r.position.x + r.size.x
	var max_y := r.position.y + r.size.y

	var p := global_position
	var hit_x := false
	var hit_y := false

	if p.x < min_x: p.x = min_x; hit_x = true
	if p.x > max_x: p.x = max_x; hit_x = true
	if p.y < min_y: p.y = min_y; hit_y = true
	if p.y > max_y: p.y = max_y; hit_y = true

	if hit_x or hit_y:
		global_position = p
		# Reflect current and target directions so we head inward immediately
		if hit_x:
			direction.x *= -1.0
			target_direction.x = -target_direction.x
		if hit_y:
			direction.y *= -1.0
			target_direction.y = -target_direction.y

		# Small nudge toward center so we don’t re-trigger clamp next frame
		var center := Vector2(min_x + max_x, min_y + max_y) * 0.5
		target_direction = (target_direction + (center - p).normalized() * 0.5).normalized()

func _set_new_direction() -> void:
	target_direction = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()
	change_timer = randf_range(change_direction_interval * 0.5, change_direction_interval * 1.5)
