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

	var fish_body := fish.get_node_or_null(FISH_BODY_PATH) as FishBody

	if fish_body:
		fish_body.set("fish_sprite_frames", base_frames)
		fish_body.set("evolution_frames", evo_frames)
	else:
		push_warning("[SPAWNER] Could not find FishBody at path '%s' under Fish scene" % FISH_BODY_PATH)

	# Add to tree, then decorate
	add_child(fish)
	fish.add_to_group("fish")
	print("[SPAWNER] Added to tree. fish group size=%d"
		% get_tree().get_nodes_in_group("fish").size())

	_spawn_intro_pop(fish)

	# Optional: fire your own hooks
	if "fish_spawned" in Events:
		Events.fish_spawned.emit(fish)
		print("[SPAWNER] Emitted fish_spawned")

	# Optional: collection discovery icon from evo (or base if evo missing)
	var icon_tex := _icon_from_frames(evo_frames if evo_frames else base_frames)
	if "collection_discover" in Events and icon_tex:
		Events.collection_discover.emit(
			species_id,
			(display_name if display_name != "" else species_id),
			icon_tex
		)


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
