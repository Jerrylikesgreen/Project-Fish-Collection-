class_name FishSpawner
extends Node2D

@export var fish_scene: PackedScene
@export var autospawn_count: int = 1

# Optional starter frames (treat as "base" frames).
@export var starter_base_frames: SpriteFrames
# Optional starter evo frames (if you want immediate evolve testing).
@export var starter_evo_frames: SpriteFrames

@export var starter_species_id: String = "Starter"
@export var starter_display_name: String = "Starter"

const FISH_BODY_PATH := "FishBody"  # adjust if your path differs

func _ready() -> void:
	Events.spawn_fish_signal.connect(_on_spawn_fish)
	print("[SPAWNER] Connected to Events.spawn_fish_signal")
	Globals.current_number_of_fish_in_tank = Globals.current_number_of_fish_in_tank + 1

	for i in range(autospawn_count):
		var base := starter_base_frames
		var evo  := starter_evo_frames
		_on_spawn_fish(base, evo, starter_species_id, starter_display_name)


func _on_spawn_fish(base_frames: SpriteFrames, evo_frames: SpriteFrames, species_id: String, display_name: String) -> void:
	print("[SPAWNER] _on_spawn_fish species='%s' | base=%s | evo=%s"
		% [species_id, str(base_frames), str(evo_frames)])

	if fish_scene == null:
		push_error("[SPAWNER] fish_scene not assigned")
		return

	var fish := fish_scene.instantiate()
	print("[SPAWNER] Instanced: %s" % fish)

	fish.set("species_id", species_id)
	fish.set("display_name", (display_name if display_name != "" else species_id))
	fish.set("evolution_sprites", evo_frames)

	var fish_body := fish.get_node_or_null(FISH_BODY_PATH)
	if fish_body:
		fish_body.set("fish_sprite_frames", base_frames)
		fish_body.set("evolution_frames", evo_frames)
	else:
		push_warning("[SPAWNER] Could not find FishBody at path '%s'" % FISH_BODY_PATH)

	add_child(fish)
	fish.add_to_group("fish")
	print("[SPAWNER] Added to tree. fish group size=%d"
		% get_tree().get_nodes_in_group("fish").size())

	_spawn_intro_pop(fish)

	if "fish_spawned" in Events:
		Events.fish_spawned.emit(fish)



func _spawn_intro_pop(fish: Node2D) -> void:
	fish.scale = Vector2(0.6, 0.6)
	if fish is CanvasItem:
		(fish as CanvasItem).modulate.a = 0.0  # fade from 0 → 1

	var t := create_tween()
	t.set_parallel(true)

	t.tween_property(fish, "scale", Vector2(4.08, 4.08), 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(fish, "scale", Vector2(4.00, 4.00), 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if fish is CanvasItem:
		t.tween_property(fish, "modulate:a", 1.0, 0.22)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	print("[SPAWNER] Intro pop tween started for %s" % fish)


func _icon_from_frames(frames: SpriteFrames) -> Texture2D:
	if frames == null:
		print("[SPAWNER] _icon_from_frames called with null frames")
		return null
	var names := frames.get_animation_names()
	print("[SPAWNER] _icon_from_frames: anim_names=%s" % names)
	if names.is_empty():
		return null
	var anim := "idle" if frames.has_animation("idle") else names[0]
	var count := frames.get_frame_count(anim)
	print("[SPAWNER] _icon_from_frames: chosen anim='%s', frame_count=%d" % [anim, count])
	if count <= 0:
		return null
	var tex := frames.get_frame_texture(anim, 0)
	print("[SPAWNER] _icon_from_frames: returning texture=%s" % str(tex))
	return tex

func _apply_material_recursive(n: Node, mat: ShaderMaterial) -> int:
	var count := 0
	if n is CanvasItem:
		var ci := n as CanvasItem
		ci.modulate = Color(1,1,1,1)        # avoid double darkening
		ci.self_modulate = Color(1,1,1,1)
		ci.material = mat
		count += 1
	for c in n.get_children():
		count += _apply_material_recursive(c, mat)
	return count

# ---- find likely drawables under a root (fallback) ----
func _find_drawables(root: Node) -> Array[CanvasItem]:
	var out: Array[CanvasItem] = []
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is CanvasItem:
			# Prefer common 2D drawables; skip invisible containers
			if n is AnimatedSprite2D or n is Sprite2D or n is MeshInstance2D or n is NinePatchRect:
				out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


# ---- build style material (your values kept) ----
const SHADER_PATH := "res://shaders/highlight_tint.gdshader"
const SHADER_MODE := 1

func _build_style_material(tint_col: Color) -> ShaderMaterial:
	var sh := load(SHADER_PATH)
	if sh == null:
		push_warning("[SPAWNER] shader not found at %s" % SHADER_PATH)
		return null
	var mat := ShaderMaterial.new()
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
	return mat

# ---- pull queued style from Events, apply, and stash on Fish ----
func _apply_fish_style_if_any(fish: Node) -> void:
	if not Events.has_method("consume_next_fish_style"):
		return

	var sty = Events.consume_next_fish_style()
	if sty == null or not sty.has("has") or sty["has"] != true:
		print("[SPAWNER] no queued fish style")
		return

	var tint: Color = sty.get("tint", Color(1,1,1,1))
	var sparkle: bool = sty.get("sparkle", false)
	var mat := _build_style_material(tint)
	if mat == null:
		return

	# Prefer the exact sprite path(s) you expect in your Fish scene
	var applied := 0
	var chosen_path := ""
	var paths := [
		"FishBody/Tilt/FishSprite",  # if your FishBody has a Tilt node
		"FishBody/FishSprite",       # common arrangement
		"FishSprite"                 # fallback name at root
	]
	for p in paths:
		var node := fish.get_node_or_null(p)
		if node and node is CanvasItem:
			applied = _apply_material_recursive(node, mat)
			chosen_path = p
			break

	# Robust fallback if none of the paths existed or drew anything
	if applied == 0:
		var drawables := _find_drawables(fish)
		for d in drawables:
			d.modulate = Color(1,1,1,1)
			d.self_modulate = Color(1,1,1,1)
			d.material = mat
			applied += 1
		chosen_path = "fallback(%d drawables)" % drawables.size()

	# Stash on Fish so FishBody can re-apply after evolve
	if fish.has_method("apply_style_material"):
		fish.apply_style_material(mat)
	else:
		fish.set("style_material", mat)

	print("[SPAWNER] applied fish style tint=%s sparkle=%s via %s -> %d CanvasItem(s)"
		% [str(tint), str(sparkle), chosen_path, applied])
