class_name FishGachaButton
extends Button
const POD = preload("res://Scenes/pod.tscn")
@onready var fish_gacha_sprite: AnimatedSprite2D = %FishGachaSprite
@onready var marker: PathFollow2D = %Marker
@onready var pods: AnimatedSprite2D = %Pods
@onready var knob: AnimatedSprite2D = %Knob
const FISH = preload("res://Scenes/fish.tscn")
@export var path_duration: float = 1.5
@export var from_ratio: float = 0.0
@export var to_ratio: float = 1.0
@export var wait_for_spawn_anim: bool = false
@export var fish_pack_pool: Array[FishPackResource]

@export var entry_cost: int = 5          # gate to press button
@export var cost_pack_a: int = 5
@export var cost_pack_b: int = 20
@export var cost_pack_c: int = 175

@export var max_fish_count:int = 3
@export var active_fish: int = 0

var _tween: Tween
var _dbg_id := "GACHA"

func _ready() -> void:

	print("[%s] _ready" % _dbg_id)
	print("[%s] config: pool_size=%d  costs={entry:%d, A:%d, B:%d, C:%d}  path{from:%f,to:%f,dur:%f}  limits live<=%d" %
		[_dbg_id, fish_pack_pool.size(), entry_cost, cost_pack_a, cost_pack_b, cost_pack_c, from_ratio, to_ratio, path_duration, max_fish_count])

	pressed.connect(_on_pressed)
	print("[%s] connected: Button.pressed -> _on_pressed" % _dbg_id)

	Events.fish_pack_selected_signal.connect(_on_fish_pack_selected)
	print("[%s] connected: Events.fish_pack_selected_signal -> _on_fish_pack_selected" % _dbg_id)

func _on_pressed() -> void:
	
	var live := get_tree().get_nodes_in_group("fish").size()
	print("[%s] _on_pressed: bubbles=%d  live=%d/%d  disabled=%s" %
		[_dbg_id, Globals.current_bubble_count, live, max_fish_count, str(disabled)])

	if Globals.current_bubble_count < entry_cost:
		Events.display_player_message("[%s][BLOCK] not enough bubbles for entry (need %d)" % [_dbg_id, entry_cost])
		print("[%s][BLOCK] entry gate failed: have=%d need=%d" % [_dbg_id, Globals.current_bubble_count, entry_cost])
		return
	if live >= max_fish_count:
		print("[%s][BLOCK] max_fish_count reached (%d/%d)" % [_dbg_id, live, max_fish_count])
		Events.display_player_message("[%s][BLOCK] max_fish_count reached" % _dbg_id)
		return
	Events._on_button_signal.emit()

	print("[%s] emitting: fish_pack_button (open chooser UI)" % _dbg_id)
	Events.fish_pack_button()
	pods.play()
	knob.play()
	

func _on_fish_pack_selected(fish_pack: String) -> void:
	print("[%s] PACK SELECTED: '%s'" % [_dbg_id, fish_pack])

	var fpr: FishPackResource = null
	var cost := 0

	# --- choose pack + cost ---
	match fish_pack:
		"A":
			if fish_pack_pool.size() > 0:
				fpr = fish_pack_pool[0]
			cost = cost_pack_a
		"B":
			if fish_pack_pool.size() > 1:
				fpr = fish_pack_pool[1]
			cost = cost_pack_b
		"C":
			if fish_pack_pool.size() > 2:
				fpr = fish_pack_pool[2]
			cost = cost_pack_c
		_:
			print("[%s][ERROR] Unknown pack key: %s" % [_dbg_id, fish_pack])
			disabled = false
			print("[%s] button disabled=false (unknown pack)" % _dbg_id)
			return

	print("[%s] pack picked: fpr=%s cost=%d" % [_dbg_id, fpr, cost])

	if fpr == null:
		print("[%s][ERROR] Pack '%s' index missing in fish_pack_pool. size=%d" %
			[_dbg_id, fish_pack, fish_pack_pool.size()])
		disabled = false
		print("[%s] button disabled=false (missing pack index)" % _dbg_id)
		return
	if not ("fish_pool" in fpr):
		print("[%s][ERROR] FishPackResource missing 'fish_pool' for pack '%s' (resource=%s)" %
			[_dbg_id, fish_pack, fpr])
		disabled = false
		print("[%s] button disabled=false (no fish_pool)" % _dbg_id)
		return

	# --- cost gate ---
	print("[%s] cost gate: pack=%s cost=%d player_bubbles=%d" %
		[_dbg_id, fish_pack, cost, Globals.current_bubble_count])
	if Globals.current_bubble_count < cost:
		print("[%s][BLOCK] Not enough bubbles for pack %s (have=%d need=%d)" %
			[_dbg_id, fish_pack, Globals.current_bubble_count, cost])
		disabled = false
		print("[%s] button disabled=false (cost gate fail)" % _dbg_id)
		return

	# Deduct
	Events.bubble_count_changed(-cost)
	print("[%s] bubbles deducted: -%d -> now=%d" %
		[_dbg_id, cost, Globals.current_bubble_count])

	# --- pick fish ---
	var fish_keys: Array = fpr.fish_pool.keys()
	print("[%s] fish_pool keys (%d): %s" % [_dbg_id, fish_keys.size(), fish_keys])

	if fish_keys.is_empty():
		print("[%s][ERROR] fish_pool is empty for pack %s" % [_dbg_id, fish_pack])
		disabled = false
		print("[%s] button disabled=false (empty fish_pool)" % _dbg_id)
		return

	var species_id: String = fish_keys.pick_random()
	print("[%s] species picked: %s" % [_dbg_id, species_id])

	if not fpr.fish_pool.has(species_id):
		print("[%s][ERROR] picked key '%s' not in fish_pool keys=%s" %
			[_dbg_id, species_id, fish_keys])
		disabled = false
		print("[%s] button disabled=false (picked missing key)" % _dbg_id)
		return

	var evolution_frames: SpriteFrames = fpr.fish_pool[species_id]
	var frames_path := (evolution_frames.resource_path if evolution_frames else "")
	print("[%s] frames resolved: %s  path=%s" %
		[_dbg_id, str(evolution_frames), frames_path])

	if evolution_frames == null:
		print("[%s][ERROR] Frames is NULL for species '%s' in pack %s" %
			[_dbg_id, species_id, fish_pack])
		disabled = false
		print("[%s] button disabled=false (null frames)" % _dbg_id)
		return

	print("[%s] SELECTED -> Pack=%s | Species=%s | Frames=%s" %
		[_dbg_id, fish_pack, species_id, str(evolution_frames)])

	# --- visuals ---
	print("[%s] visuals: pods.pause(), knob.pause(), knob.visible=false, sprite.play('Spawn'), pod.play('Spin')" % _dbg_id)
	pods.pause()
	knob.pause()
	knob.visible = false
	fish_gacha_sprite.play("Spawn")
		# --- SPAWN POD + ASSIGN DATA ---
	var pod := POD.instantiate() as AnimatedSprite2D
	print("[%s] SPAWN POD instanced: %s" % [_dbg_id, str(pod)])

	marker.add_child(pod)
	pod.position = Vector2.ZERO    # local to marker
	if pod.has_method("play"):
		pod.play()

	# If your Pod script exposes fields, set them (these checks are safe even if it doesn't)
	if "fish_pack" in pod:
		pod.fish_pack = fish_pack
	if "species_id" in pod:
		pod.species_id = species_id
	if "evolution_frames" in pod:
		pod.evolution_frames = evolution_frames
	if "frames_path" in pod:
		pod.frames_path = frames_path
	if "follow" in pod:
		pod.follow = marker
	if "from_ratio" in pod:
		pod.from_ratio = from_ratio
	if "to_ratio" in pod:
		pod.to_ratio = to_ratio
	if "path_duration" in pod:
		pod.path_duration = path_duration

	print("[%s] POD DATA: pack=%s species=%s evo_frames=%s path=%s" %
		[_dbg_id, fish_pack, species_id, str(evolution_frames), frames_path])

	# --- MOVE ALONG PATH: tween the marker so pod rides it ---
	print("[%s] path tween: from=%f to=%f dur=%f" % [_dbg_id, from_ratio, to_ratio, path_duration])
	await _run_path(from_ratio, to_ratio, path_duration)

	# --- TRANSFORM + POP ---
	if pod.has_method("play"):
		pod.play("Transform")
	await _pop_in(pod, 0.6, 1.0, 1.02, true, 0.18)

	print("[%s] waiting for pod.animation_finished..." % _dbg_id)
	await pod.animation_finished
	print("[%s] pod animation finished" % _dbg_id)

	# --- EMIT rolled + SPAWN fish (pass evo frames!) ---
	print("[%s] EMIT: fish_rolled_signal + spawn_fish | species=%s | evo_frames=%s" %
		[_dbg_id, species_id, str(evolution_frames)])
	Events.fish_rolled_signal.emit(fish_pack, species_id, evolution_frames)

	var display_name := species_id
	# If your Events.spawn_fish supports evo_frames as 4th param (recommended):
	Events.spawn_fish(null, species_id, display_name, evolution_frames)

	# Reset marker for next roll
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
