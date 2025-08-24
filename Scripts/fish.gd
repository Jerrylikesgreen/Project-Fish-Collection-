class_name Fish
extends Node2D

const BUBBLE := preload("res://Scenes/bubble.tscn")
@onready var fish_sfx: AudioStreamPlayer = %FishSFX
@onready var fish_sprite: Fish_Sprite = %FishSprite

@export var species_id: String = ""      # e.g. "Clownfish"
@export var display_name: String = ""    # e.g. "Clownfish"
@onready var bubble_spawner: Timer = %BubbleSpawner
@onready var fish_body: FishBody = $FishBody
@onready var mouth: Marker2D = %Marker2D
@onready var sell_button: Button = %SellButton
@export var icon_override: Texture2D

@export var rare_spawn_sfx_index: int = 6     # index in fish_sfx.track_pool (set what you use)
@export var rare_spawn_sfx: AudioStream       # optional direct stream fallback
var _rare_chimed: bool = false                # guard so it plays once

@onready var anim: Fish_Sprite = %FishSprite
@export var evolution_sprites: SpriteFrames
@export var spawn_every: float = 1.0

const RARITIES := ["Base","Gold","Green","Pink"]

# === Update your rarity property to notify when it changes ===
@export_enum("Base","Gold","Green","Pink") var rarity: int:
	set(value):
		var clamped := clampi(value, 0, RARITIES.size() - 1)
		if clamped == _rarity:
			# no change
			return
		_rarity = clamped
		if is_inside_tree():
			_apply_rarity_to_sprite()
			_maybe_play_rare_chime()   # <-- play if non-base
	get:
		return _rarity
var _rarity: int = 0


const RARITY_WEIGHTS := [55, 25, 15, 5]

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("fish")
	sell_button.pressed.connect(_on_sell_button_pressed)
	_rng.randomize()
	Events.selling_fish_signal.connect(_on_selling_fish_signal)
	bubble_spawner.wait_time = spawn_every
	bubble_spawner.one_shot = false
	if not bubble_spawner.timeout.is_connected(self._spawn_one):
		bubble_spawner.timeout.connect(self._spawn_one)
	bubble_spawner.start()
	fish_body.fish_ate.connect(_on_fish_ate)
	_maybe_play_rare_chime()
	rarity = _pick_random_rarity_index()
	print(rarity, " Fish")
	fish_body.evolution_signal.connect(_on_evolved)
	fish_body.evolution_frames = evolution_sprites
	fish_body.species_id = species_id
	print("[Fish] Assigned evolution_frames for species=%s | evolution_sprites=%s"
		% [species_id, str(evolution_sprites)])

func _on_evolved()->void:
	fish_sprite.set_sprite_frames(evolution_sprites)


func _spawn_one() -> void:
	var bubble: RigidBody2D = BUBBLE.instantiate()
	get_tree().current_scene.get_child(1).add_child(bubble)
	fish_sfx.set_stream(fish_sfx.track_pool[5]) 
	fish_sfx.play()
	bubble.global_position = mouth.global_position
	if fish_body._evolved:
		bubble.modulate = Color(0.0, 0.0, 0.784)
		bubble.bubble_value = 3

func _pick_random_rarity_index() -> int:
	var total := 0
	for w in RARITY_WEIGHTS:
		total += w
	var roll := _rng.randi_range(0, total - 1)
	for i in RARITY_WEIGHTS.size():
		roll -= RARITY_WEIGHTS[i]
		if roll < 0:
			return i
	return 0

func _apply_rarity_to_sprite() -> void:
	var rarity_name = RARITIES[_rarity]
	if fish_sprite:
		fish_sprite.add_rarity(rarity_name)

func _on_selling_fish_signal(enabled: bool) -> void:
	sell_button.visible = enabled
	
func _on_sell_button_pressed() -> void:
	if not Events.selling_fish:
		return
	fish_sfx.set_stream(fish_sfx.track_pool[2])
	fish_sfx.play()
	Events.bubble_count_changed(3)
	Events.fish_sold()
	await fish_sfx.finished
	queue_free()


func get_collection_key() -> String:
	return species_id

func get_collection_name() -> String:
	return display_name if display_name != "" else species_id

func get_icon_texture() -> Texture2D:
	if icon_override != null:
		return icon_override
	
	if anim and anim.sprite_frames:
		var frames := anim.sprite_frames
		var anim_name := anim.animation
		if anim_name == "" and frames.get_animation_names().size() > 0:
			return
		
		if frames.has_animation("idle"):
			anim_name = "idle"
		else:
			anim_name = frames.get_animation_names()[0]

		if frames.has_animation(anim_name) and frames.get_frame_count(anim_name) > 0:
			return frames.get_frame_texture(anim_name, 0)

	if has_node("Sprite2D"):
		var spr := $Sprite2D as Sprite2D
		if spr.texture:

			return spr.texture

	return null
	
func _on_fish_ate(r: int) -> void:

	var spawn_counts := [1, 2, 5, 10] 

	if r < 0 or r >= spawn_counts.size():
		return
		
	var count = spawn_counts[r]
	for i in count:
		await get_tree().get_frame() 
		_spawn_one()


func _maybe_play_rare_chime() -> void:
	if _rare_chimed:
		return
	if _rarity <= 0:
		return
	if fish_sfx == null:
		return

	var played := false
	if "track_pool" in fish_sfx and fish_sfx.track_pool.size() > 0:
		if rare_spawn_sfx_index >= 0 and rare_spawn_sfx_index < fish_sfx.track_pool.size():
			fish_sfx.set_stream(fish_sfx.track_pool[9])
			fish_sfx.play()
			played = true
	if not played and rare_spawn_sfx:
		fish_sfx.stream = rare_spawn_sfx
		fish_sfx.play()
		played = true

	if played:
		_rare_chimed = true
		print("Rare fish spawned: rarity=", RARITIES[_rarity], " (idx=", _rarity, ") — SFX played")
	else:
		print("Rare fish spawned but no SFX available (check rare_spawn_sfx_index or assign rare_spawn_sfx)")


func get_evolution_icon_texture() -> Texture2D:
	# Prefer FishBody.evolution_frames if available
	var evo_frames: SpriteFrames = null
	if has_node("FishBody"):
		var fb := get_node("FishBody")
		if fb:
			evo_frames = fb.get("evolution_frames")
	# Fallback to a copy cached on the Fish root (if you mirror it there)
	if evo_frames == null:
		evo_frames = self.get("evolution_sprites")

	if evo_frames == null:
		print("[Fish] get_evolution_icon_texture: evo_frames=NULL → returning NULL")
		return null

	var names := evo_frames.get_animation_names()
	if names.is_empty():
		print("[Fish] get_evolution_icon_texture: evo_frames has no animations → NULL")
		return null

	# Prefer an idle-like animation but fall back to first with frames
	var pick := ""
	for n in ["Idle", "idle"]:
		if evo_frames.has_animation(n):
			pick = n; break
	if pick == "":
		pick = names[0]
	if evo_frames.get_frame_count(pick) <= 0:
		for n in names:
			if evo_frames.get_frame_count(n) > 0:
				pick = n; break

	var tex := evo_frames.get_frame_texture(pick, 0)
	print("[Fish] get_evolution_icon_texture: pick='%s' tex=%s" % [pick, str(tex)])
	return tex
