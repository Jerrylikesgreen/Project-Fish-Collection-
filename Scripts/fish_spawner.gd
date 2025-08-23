class_name FishSpawner
extends Node2D

@export var fish_scene: PackedScene

func _ready() -> void:
	# Connect once the node enters the tree
	Events.spawn_fish_signal.connect(_on_spawn_fish)

func _on_spawn_fish(frames: SpriteFrames, species_id := "", display_name := "") -> void:
	if fish_scene == null:
		push_error("FishSpawner: fish_scene not assigned")
		return
	if frames == null:
		push_warning("FishSpawner: frames is null; skipping spawn")
		return

	var fish := fish_scene.instantiate()

	# Try to set metadata if Fish.gd defines these
	if fish is Fish:
		fish.species_id = species_id
		fish.display_name = (display_name if display_name != "" else species_id)

	# Apply SpriteFrames to the AnimatedSprite2D
	var anim_sprite: AnimatedSprite2D = null
	if fish is Fish:
		anim_sprite = fish.fish_sprite
	elif fish.has_node("AnimatedSprite2D"):
		anim_sprite = fish.get_node("AnimatedSprite2D") as AnimatedSprite2D

	if anim_sprite:
		anim_sprite.sprite_frames = frames
	else:
		push_error("FishSpawner: No AnimatedSprite2D found on spawned fish")

	add_child(fish)
	_spawn_intro_pop(fish) 
	Events.fish_spawned.emit(fish)

	# Now call the helper safely
	var icon := _icon_from_frames(frames)
	Events.collection_discover.emit(
		species_id,
		(display_name if display_name != "" else species_id),
		icon
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
		return null
	var names := frames.get_animation_names()
	if names.is_empty():
		return null
	var anim := "idle" if frames.has_animation("idle") else names[0]
	if frames.get_frame_count(anim) <= 0:
		return null
	return frames.get_frame_texture(anim, 0)
