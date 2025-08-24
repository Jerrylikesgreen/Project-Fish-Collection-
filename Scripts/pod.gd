class_name Pod
extends AnimatedSprite2D

# ----- Inject what this script needs -----
@export var dbg_id: String = "POD"

# Path motion
@export var follow: PathFollow2D          # assign %Follow in the Pod scene/parent
@export var from_ratio: float = 0.0
@export var to_ratio: float = 1.0
@export var path_duration: float = 1.5

# Data to emit
@export var fish_pack: String = "A"
@export var species_id: String = ""
@export var evolution_frames: SpriteFrames
@export var frames_path: String = ""

# Optional: a separate visual to pop-in; default to self
@export var pop_target_path: NodePath
var _pop_target: Node = null

var _tween: Tween

func _ready() -> void:
	await get_tree().get_frame()


	_pop_target = (get_node(pop_target_path) if pop_target_path != NodePath() else self)

	print("[%s] _ready: species=%s pack=%s evo_frames=%s path=%s follow=%s"
		% [dbg_id, species_id, fish_pack, str(evolution_frames), frames_path, str(follow)])

	play("Spin")

	print("[%s] path tween: from=%f to=%f dur=%f" % [dbg_id, from_ratio, to_ratio, path_duration])
	await _run_path(from_ratio, to_ratio, path_duration)

	print("[%s] transform: play('Transform') + pop_in" % dbg_id)
	play("Transform")
	await _pop_in(_pop_target, 0.6, 1.0, 1.02, true, 0.18)

	print("[%s] waiting for animation_finished..." % dbg_id)
	await animation_finished
	print("[%s] animation finished" % dbg_id)

	# Emit events (data-only responsibility here)
	if evolution_frames:
		print("[%s] EMIT: fish_rolled_signal + spawn_fish | species=%s | evo_frames=%s"
			% [dbg_id, species_id, str(evolution_frames)])
	else:
		push_warning("[%s] evolution_frames is NULL; emitting anyway" % dbg_id)

	Events.fish_rolled_signal.emit(fish_pack, species_id, evolution_frames)

	var display_name := species_id
	# Events.spawn_fish(null, species_id, display_name, evolution_frames)

	# Reset follow position so the pod is ready for reuse if needed
	if follow:
		follow.progress_ratio = from_ratio
	print("[%s] done" % dbg_id)


func _run_path(from: float, to: float, dur: float) -> void:
	if not follow:
		push_warning("[%s] follow is NULL; skipping path tween" % dbg_id)
		return
	if _tween:
		print("[%s] tween: killing previous tween=%s" % [dbg_id, _tween])
		_tween.kill()
	follow.loop = false
	follow.progress_ratio = from
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	print("[%s] tween: follow.progress_ratio %f -> %f over %f" % [dbg_id, from, to, dur])
	_tween.tween_property(follow, "progress_ratio", to, dur)
	await _tween.finished
	print("[%s] tween: finished (progress_ratio=%f)" % [dbg_id, follow.progress_ratio])


func _pop_in(node: Node, from_s: float = 0.6, to_s: float = 1.0, overshoot: float = 1.18, fade: bool = true, t: float = 0.22) -> void:
	var ci := node as CanvasItem
	if fade and ci:
		print("[%s] pop_in: fade 0 -> 1 over %f on %s" % [dbg_id, t, ci])
		ci.modulate.a = 0.0

	if node is Node2D:
		print("[%s] pop_in: Node2D scale %f -> %f (overshoot %f)" % [dbg_id, from_s, to_s, overshoot])
		(node as Node2D).scale = Vector2(from_s, from_s)
	elif node is Control:
		print("[%s] pop_in: Control center + scale %f -> %f (overshoot %f)" % [dbg_id, from_s, to_s, overshoot])
		(node as Control).pivot_offset = (node as Control).size * 0.5
		(node as Control).scale = Vector2(from_s, from_s)

	var tw := create_tween()
	if fade and ci:
		tw.set_parallel(true)
		tw.tween_property(ci, "modulate:a", 1.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)

	tw.tween_property(node, "scale", Vector2(to_s * overshoot, to_s * overshoot), t)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2(to_s, to_s), 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	print("[%s] pop_in: finished for node=%s" % [dbg_id, node])
