class_name FishBody
extends CharacterBody2D

signal evolution_signal
signal fish_ate(r:int)

@export var fish_sprite_frames: SpriteFrames
@export var evolution_frames: SpriteFrames
@export var species_id: String = ""
@onready var fish_sensor: FishSensor = %FishSensor
@onready var fish_sfx: AudioStreamPlayer = %FishSFX
@onready var marker_2d: Marker2D = %Marker2D
@onready var fish_sprite: AnimatedSprite2D = %FishSprite
@onready var hunger_tick: Timer = %HungerTick

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
@export var _is_hungry: bool = false

# ── State ───────────────────────────────────────────────────
var direction: Vector2 = Vector2.RIGHT
var target_direction: Vector2 = Vector2.RIGHT
var change_timer: float = 0.0
var _consumed_food_value: int = 0
var _evolved: bool = false

func _ready() -> void:
	randomize()
	_set_new_direction()
	hunger_tick.timeout.connect(_on_hunger_tick)

func _physics_process(delta: float) -> void:
	if !_is_hungry:
		fish_sprite.play("Idle")
	change_timer -= delta
	# --- evade edges first ---
	var evading: bool = _apply_edge_avoidance(delta)

	# --- random wander if not evading and timer elapsed ---
	if change_timer <= 0.0 and not evading:
		_set_new_direction()

	# --- seek food if hungry (overrides target) ---
	if _is_hungry and not evading and fish_sensor:
		var t := fish_sensor.get_target()
		if t and is_instance_valid(t):
			var to_food := (t.global_position - global_position)
			if to_food.length_squared() > 1e-6:
				target_direction = to_food.normalized()

	# --- steer toward target (faster when evading) ---
	var turn := turn_smoothness * (evade_turn_multiplier if evading else 1.0)
	target_direction = target_direction.normalized()
	direction = direction.lerp(target_direction, delta * turn).normalized()

	# --- move ---
	velocity = direction * speed
	move_and_slide()
	_eat_fish()
	_reflect_if_clamped()
	if direction.length_squared() > 0.0:
		var target_rot := direction.angle()
		fish_sprite.rotation = lerp_angle(fish_sprite.rotation, target_rot, delta * 10.0)

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
func _apply_edge_avoidance(_delta: float) -> bool:
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

func _eat_fish() -> void:
	if not _is_hungry:
		return
	for i in range(get_slide_collision_count()):
		var c := get_slide_collision(i)
		var hit := c.get_collider()
		if hit:
			print("Fish ate:", hit._rarity)
			hit.call_deferred("queue_free")
			if fish_sensor:
				fish_sensor.consume_food(hit)
			_consumed_food_value += 1 
			emit_signal("fish_ate", hit._rarity)
			fish_sprite.play("Eat")
			_is_hungry = false
			_check_hunger_value()
			if fish_sfx and "track_pool" in fish_sfx and fish_sfx.track_pool.size() > 8:
				fish_sfx.set_stream(fish_sfx.track_pool[8])

func _on_hunger_tick() -> void:
	if not _is_hungry:
		_is_hungry = true
		fish_sprite.play("Cry")

func _check_hunger_value() -> void:
	if _evolved:
		return
	if _consumed_food_value > 3:
		_switch_frames_and_play(evolution_frames, ["Evolve", "Idle", "idle"])
		_evolved = true

		var p := get_parent()
		if p != null and p is Fish:
			var f := p as Fish
			var show_name := f.get_collection_name()
			Events.display_player_message("It grew into " + show_name + "!")
			print("[FishBody] Evolution reveal -> ", show_name)

		var old_hunger_tick := hunger_tick.wait_time
		hunger_tick.wait_time = old_hunger_tick * 1.5



func _switch_frames_and_play(evolution_frames: SpriteFrames, preferred: Array[String] = ["Evolve", "Idle", "idle"]) -> void:
	if evolution_frames == null:
		push_warning("FishBody: evolution_frames is NULL — cannot switch")
		return

	print("[FishBody] Switching to evolution_frames=%s" % str(evolution_frames))
	fish_sprite.sprite_frames = evolution_frames
		# after: fish_sprite.sprite_frames = evolution_frames (and you picked/played anim)
	var parent_fish := get_parent()
	var species_id_to_emit := species_id
	var reveal_name := species_id
	
	if parent_fish and parent_fish.has_method("get_collection_key"):
		species_id_to_emit = String(parent_fish.get_collection_key())
	if parent_fish and parent_fish.has_method("get_collection_name"):
		reveal_name = String(parent_fish.get_collection_name())
	
	var icon_tex := _icon_from_frames(evolution_frames)
	
	if "collection_discover" in Events:
		Events.collection_discover.emit(species_id_to_emit, reveal_name, icon_tex)
		print("[FishBody] emitted collection_discover id=%s name=%s icon=%s"
			% [species_id_to_emit, reveal_name, str(icon_tex)])
	




	# Pick an animation to play on the new frames
	var names := evolution_frames.get_animation_names()
	print("[FishBody] Applied evolution_frames. Animations=%s" % names)
	if names.is_empty():
		push_warning("FishBody: new SpriteFrames has no animations")
		return

	var pick := ""
	for n in preferred:
		if evolution_frames.has_animation(n):
			pick = n
			break
	if pick == "":
		pick = names[0]

	print("[FishBody] Playing animation '%s' after evolve" % pick)
	fish_sprite.animation = pick
	fish_sprite.play(pick)

func _icon_from_frames(frames: SpriteFrames) -> Texture2D:
	if frames == null:
		return null
	var anim := ""
	if frames.has_animation("Idle"):
		anim = "Idle"
	elif frames.has_animation("idle"):
		anim = "idle"
	else:
		var names := frames.get_animation_names()
		if names.size() > 0:
			anim = names[0]
		else:
			return null
	var count := frames.get_frame_count(anim)
	if count <= 0:
		return null
	return frames.get_frame_texture(anim, 0)
