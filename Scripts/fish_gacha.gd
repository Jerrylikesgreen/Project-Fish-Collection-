class_name FishGachaButton
extends Button

@onready var fish_gacha_sprite: AnimatedSprite2D = %FishGachaSprite
@onready var follow: PathFollow2D = %Follow
@onready var pod: AnimatedSprite2D = %Pod
@onready var pods: AnimatedSprite2D = %Pods
@onready var knob: AnimatedSprite2D = %Knob

@export var path_duration: float = 1.5
@export var from_ratio: float = 0.0
@export var to_ratio: float = 1.0
@export var wait_for_spawn_anim: bool = false
@export var fish_pack_pool: Array[FishPackResource]

# ✅ make costs POSITIVE
@export var entry_cost: int = 5          # gate to press button
@export var cost_pack_a: int = 5
@export var cost_pack_b: int = 20
@export var cost_pack_c: int = 175

@export var max_fish_count:int = 3
@export var active_fish: int = 0

var _tween: Tween

func _ready() -> void:
	pressed.connect(_on_pressed)
	# Listen for the simple pack selection (1 arg)
	Events.fish_pack_selected_signal.connect(_on_fish_pack_selected)

func _on_pressed() -> void:
	if Globals.current_bubble_count < entry_cost:
		return
	if active_fish >= max_fish_count:
		return

	pods.play("Running")
	knob.visible = true
	knob.play("Running")
	disabled = true
	Events.fish_pack_button()  # opens the pack choice UI elsewhere

func _on_fish_pack_selected(fish_pack: String) -> void:
	var fpr: FishPackResource
	var cost := 0
	match fish_pack:
		"A":
			fpr = fish_pack_pool[0]
			cost = cost_pack_a
		"B":
			fpr = fish_pack_pool[1]
			cost = cost_pack_b
		"C":
			fpr = fish_pack_pool[2]
			cost = cost_pack_c
		_:
			disabled = false
			return

	if Globals.current_bubble_count < cost:
		disabled = false
		return
	Events.bubble_count_changed(-cost)  # ✅ subtract

	var fish_keys: Array = fpr.fish_pool.keys()
	if fish_keys.is_empty():
		disabled = false
		return

	var species_id: String = fish_keys.pick_random()
	var frames: SpriteFrames = fpr.fish_pool[species_id]

	print("Selected Pack:", fish_pack, " | Random Fish:", species_id, " | Frames:", frames)

	pods.pause()
	knob.pause()
	knob.visible = false
	fish_gacha_sprite.play("Spawn")
	pod.play("Spin")

	await _run_path(from_ratio, to_ratio, path_duration)
	
	pod.play("Transform")
	await _pop_in(pod, 0.6, 4.0, 1.02, true, 0.18)
	await pod.animation_finished

	Events.fish_rolled_signal.emit(fish_pack, species_id, frames)

	var display_name := species_id  
	Events.spawn_fish(frames, species_id, display_name)

	follow.progress_ratio = from_ratio
	disabled = false

func _run_path(from: float, to: float, dur: float) -> void:
	if _tween: _tween.kill()
	follow.loop = false
	follow.progress_ratio = from
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(follow, "progress_ratio", to, dur)
	await _tween.finished

func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED and scale != Vector2.ONE:
		scale = Vector2.ONE

func _pop_in(node: Node, from_s: float = 0.6, to_s: float = 1.0, overshoot: float = 1.08, fade: bool = true, t: float = 0.22) -> void:
	var ci := node as CanvasItem
	if fade and ci:
		ci.modulate.a = 0.0

	if node is Node2D:
		# If your sprite isn’t centered at its middle, set its pivot here:
		# (For Sprite2D/AnimatedSprite2D: ensure centered=true, or set pivot_offset)
		(node as Node2D).scale = Vector2(from_s, from_s)
	elif node is Control:
		(node as Control).pivot_offset = (node as Control).size * 0.5
		(node as Control).scale = Vector2(from_s, from_s)

	var tw := create_tween()

	# 1) Fade runs in parallel (optional)
	if fade and ci:
		tw.set_parallel(true)
		tw.tween_property(ci, "modulate:a", 1.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)

	# 2) Scale overshoot then settle (sequential!)
	tw.tween_property(node, "scale", Vector2(to_s * overshoot, to_s * overshoot), t)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2(to_s, to_s), 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tw.finished
