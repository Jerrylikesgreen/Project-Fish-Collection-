class_name FishSpawner
extends Node2D
@export var fish_scene: PackedScene

# NEW: starter config
@export var autospawn_count: int = 1
@export var starter_frames: SpriteFrames
@export var starter_species_id: String = "Starter"
@export var starter_display_name: String = "Starter"

func _ready() -> void:
	Events.spawn_fish_signal.connect(_on_spawn_fish)

	for i in autospawn_count:
		if starter_frames:
			_on_spawn_fish(starter_frames, starter_species_id, starter_display_name)

	

func _on_spawn_fish(evolution_frames: SpriteFrames, species_id := "", display_name := "") -> void:
	print("[SPAWNER] _on_spawn_fish species='%s' (IGNORING incoming frames; using Fish scene defaults)" % species_id)

	if fish_scene == null:
		push_error("[SPAWNER] fish_scene not assigned"); return

	var fish := fish_scene.instantiate()
	print("[SPAWNER] Instanced: %s" % fish)

	# Set metadata before adding to tree
	if fish is Fish:
		fish.species_id = species_id
		fish.display_name = (display_name if display_name != "" else species_id)
		fish.evolution_sprites = evolution_frames

	# Add to tree so onready vars are valid
	add_child(fish)
	print("[SPAWNER] Added to tree (onready initialized)")

	_spawn_intro_pop(fish)

	if "fish_spawned" in Events:
		Events.fish_spawned.emit(fish)
		print("[SPAWNER] Emitted fish_spawned")


	_spawn_intro_pop(fish)
	if "fish_spawned" in Events:
		Events.fish_spawned.emit(fish)

	var evolution_icon := _icon_from_frames(evolution_frames)
	if "collection_discover" in Events:
		Events.collection_discover.emit(
			species_id,
			(display_name if display_name != "" else species_id),
			evolution_icon
		)


func _spawn_intro_pop(fish: Node2D) -> void:
	fish.scale = Vector2(0.6, 0.6)
	if fish is CanvasItem:
		fish.modulate.a = 0.0  # fade from 0 → 1

	var t := create_tween()
	t.set_parallel() 

	t.tween_property(fish, "scale", Vector2(4.08, 4.08), 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(fish, "scale", Vector2(4.00, 4.00), 0.10)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if fish is CanvasItem:
		t.tween_property(fish, "modulate:a", 1.0, 0.22)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
