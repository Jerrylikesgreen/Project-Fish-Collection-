class_name FishGachaButton
extends Button

const POD = preload("res://Scenes/pod.tscn")
const FISH = preload("res://Scenes/fish.tscn")

@onready var fish_gacha_sprite: AnimatedSprite2D = %FishGachaSprite
@onready var marker: PathFollow2D = %Marker
@onready var pods: AnimatedSprite2D = %Pods
@onready var knob: AnimatedSprite2D = %Knob

@export var path_duration: float = 1.5
@export var from_ratio: float = 0.0
@export var to_ratio: float = 1.0
@export var wait_for_spawn_anim: bool = false
@export var fish_pack_pool: Array[FishPackResource]

@export var entry_cost: int = 5
@export var cost_pack_a: int = 5
@export var cost_pack_b: int = 20
@export var cost_pack_c: int = 175

@export var active_fish: int = 0

var _tween: Tween
var _dbg_id := "GACHA"


const LINES_GACHA_PRESS: Array[String] = [
	"Give it a spin.",
	"Crank the handle.",
	"Let’s roll one.",
	"Spin up a pod.",
	"One pull coming up.",
	"Rolling the gacha.",
	"Here we go."
]

const LINES_PACK_PROMPT: Array[String] = [
	"Choose a pack: A, B, or C.",
	"Which pack will it be—A, B, or C?",
	"Make your pick: A, B, or C.",
	"Time to pick a pack: A, B, or C.",
	"Pick a pack to roll: A, B, or C."
]


const LINES_NEED_ENTRY: Array[String] = [
	"Need %d more bubbles to roll.",
	"You're %d bubbles short.",
	"Almost there—%d more bubbles.",
	"Just %d bubbles to start."
]

const LINES_TANK_FULL: Array[String] = [
	"Tank is full (%d/%d). Sell or upgrade to add more.",
	"No space left (%d/%d).",
	"You're at capacity (%d/%d).",
	"Max fish reached (%d/%d)."
]


func _ready() -> void:
	print("[%s] _ready" % _dbg_id)
	print("[%s] config: pool_size=%d  costs={entry:%d, A:%d, B:%d, C:%d}  path{from:%f,to:%f,dur:%f}  limits live<=%d" %
		[_dbg_id, fish_pack_pool.size(), entry_cost, cost_pack_a, cost_pack_b, cost_pack_c, from_ratio, to_ratio, path_duration, Globals.max_fish_count])

	pressed.connect(_on_pressed)
	print("[%s] connected: Button.pressed -> _on_pressed" % _dbg_id)

	Events.fish_pack_selected_signal.connect(_on_fish_pack_selected)
	print("[%s] connected: Events.fish_pack_selected_signal -> _on_fish_pack_selected" % _dbg_id)

func _on_pressed() -> void:
	var live := get_tree().get_nodes_in_group("fish").size()
	print("[%s] _on_pressed: bubbles=%d  live=%d/%d  disabled=%s" %
		[_dbg_id, Globals.current_bubble_count, live, Globals.max_fish_count, str(disabled)])

	if Globals.current_bubble_count < entry_cost:
		var short := entry_cost - Globals.current_bubble_count
		Events.display_player_message(_pick_line(LINES_NEED_ENTRY, [short]))
		print("[%s][BLOCK] entry gate failed: have=%d need=%d" %
			[_dbg_id, Globals.current_bubble_count, entry_cost])
		return
	
	if live >= Globals.max_fish_count:
		Events.display_player_message(_pick_line(LINES_TANK_FULL, [live, Globals.max_fish_count]))
		print("[%s][BLOCK] max_fish_count reached (%d/%d)" % [_dbg_id, live, Globals.max_fish_count])
		return
	

	Events._on_button_signal.emit()
	Events.display_player_message(_pick_line(LINES_GACHA_PRESS))
	print("[%s] opening pack menu (quiet)" % _dbg_id)
	Events.emit_signal("fish_pack_button_pressed")
	pods.play()
	knob.play()
	disabled = true


# Lightweight copy system (no emojis, no spoilers)
func _pick(lines: Array[String]) -> String:
	return lines[randi() % lines.size()]

func _pickf(weights_any: Array) -> int:
	var weights: Array[float] = []
	weights.resize(weights_any.size())
	for i in weights_any.size():
		weights[i] = float(weights_any[i])

	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return 0
	var r := randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if r <= acc:
			return i
	return weights.size() - 1



const LINES_PICKED_PACK := [
	"Pack %s selected.",
	"Going with Pack %s.",
	"Pack %s it is."
]

const LINES_PACK_TOO_EXPENSIVE := [
	"Pack %s costs %d bubbles. You're %d short.",
	"Need %d more bubbles for Pack %s (cost: %d).",
	"Not enough bubbles yet—%d more for Pack %s."
]

# ----------------- TINT / SHADER CONFIG (define ONCE) -----------------
const PACK_TINTS := {
	"A": Color(0.08, 0.42, 1.00, 1.00),  # blue
	"B": Color(1.00, 0.60, 0.10, 1.00),  # orange
	"C": Color(1.00, 0.20, 0.20, 1.00),  # red
}
const POD_TINT_SPARKLE := Color(0.55, 0.45, 1.00, 1.00)

const SHADER_PATH := "res://shaders/highlight_tint.gdshader"
const SHADER_MODE := 1  # 1 = HSV replace, 2 = grayscale colorize

func _pack_key(s: String) -> String:
	if s == null: return ""
	return s.strip_edges().to_upper()

func _roll_sparkle() -> bool:
	return randf() < 0.05  # 5%

func _apply_pod_tint_recursive(root: Node, mat: ShaderMaterial) -> void:
	if root is CanvasItem:
		var ci := root as CanvasItem
		ci.modulate = Color(1,1,1,1)
		ci.self_modulate = Color(1,1,1,1)
		ci.material = mat
	for c in root.get_children():
		_apply_pod_tint_recursive(c, mat)

func _build_pod_material_for(tint_col: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh := load(SHADER_PATH)
	mat.shader = sh
	mat.set_shader_parameter("mode", SHADER_MODE)
	mat.set_shader_parameter("tint_color", tint_col)
	mat.set_shader_parameter("strength", 1.0)
	mat.set_shader_parameter("preserve_whites", true)
	mat.set_shader_parameter("highlight_keep", 0.90)
	mat.set_shader_parameter("softness", 0.12)
	mat.set_shader_parameter("preserve_luma", true)
	mat.set_shader_parameter("value_gain", 1.15)
	mat.set_shader_parameter("lift", 0.08)
	print("[GACHA] shader=", sh, " path=", (sh.resource_path if sh else "<null>"))
	print("[GACHA] params: mode=", mat.get_shader_parameter("mode"),
		" tint=", mat.get_shader_parameter("tint_color"),
		" strength=", mat.get_shader_parameter("strength"))
	return mat

func _apply_pod_tint_strong(pod: Node, tint_col: Color) -> ShaderMaterial:
	var mat := _build_pod_material_for(tint_col)
	_apply_pod_tint_recursive(pod, mat)        # now
	pod.call_deferred("set", "material", mat)  # next frame (beats _ready/anim tracks)
	for child in pod.get_children():
		if child is CanvasItem:
			child.call_deferred("set", "material", mat)
	return mat
# ----------------------------------------------------------------------






	Events._on_button_signal.emit()

	Events.fish_pack_button_quiet()

	pods.play()
	knob.play()

func _on_fish_pack_selected(fish_pack: String) -> void:
	print("[%s] PACK SELECTED: '%s'" % [_dbg_id, fish_pack])

	# --- pick pack + cost ---
	var fpr: FishPackResource = null
	var cost := 0
	match fish_pack:
		"A":
			if fish_pack_pool.size() > 0: fpr = fish_pack_pool[0]
			cost = cost_pack_a
		"B":
			if fish_pack_pool.size() > 1: fpr = fish_pack_pool[1]
			cost = cost_pack_b
		"C":
			if fish_pack_pool.size() > 2: fpr = fish_pack_pool[2]
			cost = cost_pack_c
		_:
			print("[%s][ERROR] Unknown pack key: %s" % [_dbg_id, fish_pack])
			disabled = false
			return

	print("[%s] pack picked: fpr=%s cost=%d" % [_dbg_id, fpr, cost])
	if fpr == null:
		print("[%s][ERROR] Pack '%s' index missing in fish_pack_pool. size=%d" %
			[_dbg_id, fish_pack, fish_pack_pool.size()])
		disabled = false
		return
	if not ("fish_pool" in fpr):
		print("[%s][ERROR] FishPackResource missing 'fish_pool' for pack '%s' (resource=%s)" %
			[_dbg_id, fish_pack, fpr])
		disabled = false
		return

	# --- cost gate ---
	print("[%s] cost gate: pack=%s cost=%d player_bubbles=%d" %
		[_dbg_id, fish_pack, cost, Globals.current_bubble_count])
	if Globals.current_bubble_count < cost:
		var short := cost - Globals.current_bubble_count
		Events.display_player_message(_pick_line(LINES_PACK_TOO_EXPENSIVE, [fish_pack, cost, short]))
		print("[%s][BLOCK] Not enough bubbles for pack %s (have=%d need=%d)" %
			[_dbg_id, fish_pack, Globals.current_bubble_count, cost])
		disabled = false
		return

	# Deduct + confirm
	Events.bubble_count_changed(-cost)
	print("[%s] bubbles deducted: -%d -> now=%d" %
		[_dbg_id, cost, Globals.current_bubble_count])
	Events.display_player_message(_pick_line(LINES_PICKED_PACK, [fish_pack]))

	# --- pick fish ---
	var fish_keys: Array = fpr.fish_pool.keys()
	print("[%s] fish_pool keys (%d): %s" % [_dbg_id, fish_keys.size(), fish_keys])
	if fish_keys.is_empty():
		print("[%s][ERROR] fish_pool is empty for pack %s" % [_dbg_id, fish_pack])
		disabled = false
		return

	var species_id: String = fish_keys.pick_random()
	print("[%s] species picked: %s" % [_dbg_id, species_id])
	if not fpr.fish_pool.has(species_id):
		print("[%s][ERROR] picked key '%s' not in fish_pool keys=%s" %
			[_dbg_id, species_id, fish_keys])
		disabled = false
		return

	var evolution_frames: SpriteFrames = fpr.fish_pool[species_id]
	var frames_path := (evolution_frames.resource_path if evolution_frames else "")
	print("[%s] frames resolved: %s  path=%s" %
		[_dbg_id, str(evolution_frames), frames_path])
	if evolution_frames == null:
		print("[%s][ERROR] Frames is NULL for species '%s' in pack %s" %
			[_dbg_id, species_id, fish_pack])
		disabled = false
		return

	print("[%s] SELECTED -> Pack=%s | Species=%s | Frames=%s" %
		[_dbg_id, fish_pack, species_id, str(evolution_frames)])

	# visuals
	pods.pause()
	knob.pause()
	knob.visible = false
	fish_gacha_sprite.play("Spawn")

	# --- spawn pod ---
	var pod := POD.instantiate() as AnimatedSprite2D
	print("[%s] SPAWN POD instanced: %s" % [_dbg_id, str(pod)])
	marker.add_child(pod)
	pod.position = Vector2.ZERO
	if pod.has_method("play"):
		pod.play()

	# ---- tint / shader ----
	var k := _pack_key(fish_pack)
	var tint_col: Color = PACK_TINTS.get(k, PACK_TINTS["A"])
	var sparkle := _roll_sparkle()
	if sparkle:
		tint_col = POD_TINT_SPARKLE
	var pod_mat := _apply_pod_tint_strong(pod, tint_col)
	print("[%s] POD shader applied | pack=%s sparkle=%s color=%s" %
		[_dbg_id, k, str(sparkle), str(tint_col)])
	if sparkle:
		var tw := create_tween()
		tw.tween_property(pod_mat, "shader_parameter/lift", 0.18, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(pod_mat, "shader_parameter/lift", 0.08, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# pass-through
	if "fish_pack" in pod:        pod.fish_pack        = fish_pack
	if "species_id" in pod:       pod.species_id       = species_id
	if "evolution_frames" in pod: pod.evolution_frames = evolution_frames
	if "frames_path" in pod:      pod.frames_path      = frames_path
	if "follow" in pod:           pod.follow           = marker
	if "from_ratio" in pod:       pod.from_ratio       = from_ratio
	if "to_ratio" in pod:         pod.to_ratio         = to_ratio
	if "path_duration" in pod:    pod.path_duration    = path_duration

	print("[%s] POD DATA: pack=%s species=%s evo_frames=%s path=%s" %
		[_dbg_id, fish_pack, species_id, str(evolution_frames), frames_path])

	# move along path
	print("[%s] path tween: from=%f to=%f dur=%f" % [_dbg_id, from_ratio, to_ratio, path_duration])
	await _run_path(from_ratio, to_ratio, path_duration)

	# transform + pop in
	if pod.has_method("play"):
		pod.play("Transform")
	pod.material = pod_mat
	await _pop_in(pod, 0.6, 1.0, 1.02, true, 0.18)

	print("[%s] waiting for pod.animation_finished..." % _dbg_id)
	await pod.animation_finished
	print("[%s] pod animation finished" % _dbg_id)

	# emit + spawn fish
	print("[%s] EMIT: fish_rolled_signal + spawn_fish | species=%s | evo_frames=%s" %
		[_dbg_id, species_id, str(evolution_frames)])
	Events.fish_rolled_signal.emit(fish_pack, species_id, evolution_frames)
	var display_name := species_id
	Events.spawn_fish(null, species_id, display_name, evolution_frames)

	# pop out + cleanup
	await _pop_out(pod, 0.6, true, 0.16)
	marker.progress_ratio = from_ratio
	print("[%s] cleanup: marker.progress_ratio=%f" % [_dbg_id, marker.progress_ratio])


func _run_path(from: float, to: float, dur: float) -> void:
	if _tween:
		print("[%s] tween: killing previous tween=%s" % [_dbg_id, _tween])
		_tween.kill()
	marker.loop = false
	marker.progress_ratio = from
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	print("[%s] tween: marker.progress_ratio %f -> %f over %f" % [_dbg_id, from, to, dur])
	_tween.tween_property(marker, "progress_ratio", to, dur)
	await _tween.finished
	print("[%s] tween: finished (progress_ratio=%f)" % [_dbg_id, marker.progress_ratio])

func _pop_in(node: Node, from_s: float = 0.6, to_s: float = 1.0, overshoot: float = 1.08, fade: bool = true, t: float = 0.22) -> void:
	var ci = node as CanvasItem
	if fade and ci:
		print("[%s] pop_in: fade from 0 -> 1 over %f on %s" % [_dbg_id, t, ci])
		ci.modulate.a = 0.0
	if node is Node2D:
		print("[%s] pop_in: Node2D scale %f -> %f (overshoot %f)" % [_dbg_id, from_s, to_s, overshoot])
		(node as Node2D).scale = Vector2(from_s, from_s)
	elif node is Control:
		print("[%s] pop_in: Control pivot to center, scale %f -> %f (overshoot %f)" % [_dbg_id, from_s, to_s, overshoot])
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
	print("[%s] pop_in: finished for node=%s" % [_dbg_id, node])

func _pop_out(node: Node, to_s: float = 0.6, fade: bool = true, t: float = 0.18, free_on_end: bool = true) -> void:
	var ci: CanvasItem = node as CanvasItem
	var tw := create_tween()
	if fade and ci:
		tw.set_parallel(true)
		tw.tween_property(ci, "modulate:a", 0.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.set_parallel(false)
	tw.tween_property(node, "scale", Vector2(1.02, 1.02), 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "scale", Vector2(to_s, to_s), t)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	print("[%s] pop_out: finished for node=%s" % [_dbg_id, node])
	if free_on_end and is_instance_valid(node):
		node.queue_free()


func _pick_line(lines: Array, args: Array = []) -> String:
	if lines.is_empty():
		return ""
	var i := randi() % lines.size()
	var s: String = String(lines[i])
	return (s % args) if not args.is_empty() else s
