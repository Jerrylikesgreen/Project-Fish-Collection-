class_name Fish
extends Node2D

# Bubble tier -> value granted
const BUBBLE_VALUES := [1, 2, 3, 5]  # Normal, Uncommon, Rare, Ultra

# Baseline odds (weights). Tweak to taste.
const BUBBLE_WEIGHTS_BASE := [75, 20, 4, 1]

# When evolved, shift away from Common toward higher tiers.
# Index order: [Common, Uncommon, Rare, Ultra]
const EVOLVED_MULT := [0.8, 1.3, 2.0, 2.5]

# Extra bias by fish rarity (your RARITIES order: Base, Gold, Green, Pink).
# Each row multiplies the 4 bubble tiers respectively.
const FISH_RARITY_MULTS := [
	[1.00, 1.00, 1.00, 1.00],  # Base fish
	[0.85, 1.20, 1.60, 2.00],  # Gold
	[0.75, 1.30, 1.90, 2.40],  # Green
	[0.60, 1.40, 2.20, 3.00],  # Pink
]


const BUBBLE := preload("res://Scenes/bubble.tscn")
@onready var fish_sfx: AudioStreamPlayer = %FishSFX
@onready var fish_sprite: Fish_Sprite = %FishSprite
@export var fish_sell_value: int = 3
@export var species_id: String = ""      # e.g. "Clownfish"
@export var display_name: String = ""    # e.g. "Clownfish"
@onready var bubble_spawner: Timer = %BubbleSpawner
@onready var fish_body: FishBody = $FishBody
@onready var mouth: Marker2D = %Marker2D
@onready var sell_button: Button = %SellButton
@export var icon_override: Texture2D
@export var rare_spawn_sfx_index: int = 6     # index in fish_sfx.track_pool (set what you use)
@export var rare_spawn_sfx: AudioStream       # optional direct stream fallback
@onready var anim: Fish_Sprite = %FishSprite
@export var evolution_sprites: SpriteFrames
@export var spawn_every: float = 1.0
@export var shiny_shader_pool:Array[ShaderMaterial]

@export_enum("Base", "Gold", "Green", "Pink") var rarity: int 




var _rarity: int = 0
const RARITY_WEIGHTS := [55, 25, 15, 5]
const RARITIES := ["Base","Gold","Green","Pink"]
var _rare_chimed: bool = false                # guard so it plays once
var _rng := RandomNumberGenerator.new()
var style_material: ShaderMaterial = null

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
	print(rarity, " Fish Rarity")
	fish_body.evolution_signal.connect(_on_evolved)
	fish_body.evolution_frames = evolution_sprites
	fish_body.species_id = species_id
	_apply_rarity_to_sprite()
	print("[Fish] Assigned evolution_frames for species=%s | evolution_sprites=%s"
		% [species_id, str(evolution_sprites)])

func _on_evolved()->void:
	fish_sprite.set_sprite_frames(evolution_sprites)


func _spawn_one() -> void:
	var bubble: RigidBody2D = BUBBLE.instantiate()
	get_tree().current_scene.get_child(1).add_child(bubble)

	# SFX (keep what you had)
	if fish_sfx and "track_pool" in fish_sfx and fish_sfx.track_pool.size() > 5:
		fish_sfx.set_stream(fish_sfx.track_pool[5])
		fish_sfx.play()

	bubble.global_position = mouth.global_position

	# Build weights from evolution + fish rarity
	var evolved := (fish_body != null and fish_body._evolved)
	var weights := _build_bubble_weights(evolved, rarity)  # rarity is your 0..3 enum
	
	var tier := _pick_by_weights(weights)   # 0..3
	var value = BUBBLE_VALUES[tier]        # 1,2,3,5

	bubble.bubble_value = value
	_apply_bubble_visual(bubble, value)





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
	fish_sprite.add_rarity(rarity)
	fish_sell_value = rarity * rarity + 3

func _on_selling_fish_signal(enabled: bool) -> void:
	sell_button.visible = enabled
	
func _on_sell_button_pressed() -> void:
	if not Events.selling_fish:
		return
	fish_sfx.set_stream(fish_sfx.track_pool[2])
	fish_sfx.play()
	Events.bubble_count_changed(fish_sell_value)
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




func apply_style_material(mat: ShaderMaterial) -> void:
	style_material = mat
	var spr := get_node_or_null("FishBody/Tilt/FishSprite")
	if spr == null:
		spr = get_node_or_null("FishBody/FishSprite")
	if spr and spr is CanvasItem:
		(spr as CanvasItem).modulate = Color(1,1,1,1)
		(spr as CanvasItem).self_modulate = Color(1,1,1,1)
		(spr as CanvasItem).material = mat
		print("[Fish] style material applied to %s" % spr.get_path())

func _pick_by_weights(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	if total <= 0:
		return 0
	var roll := _rng.randi_range(0, total - 1)
	for i in range(weights.size()):
		roll -= int(weights[i])
		if roll < 0:
			return i
	return 0

func _build_bubble_weights(evolved: bool, fish_rarity_idx: int) -> Array:
	var w := BUBBLE_WEIGHTS_BASE.duplicate()
	var rarity_idx := clampi(fish_rarity_idx, 0, FISH_RARITY_MULTS.size() - 1)
	var rm = FISH_RARITY_MULTS[rarity_idx]
	for i in range(w.size()):
		var mult = rm[i] * (EVOLVED_MULT[i] if evolved else 1.0)
		var v = float(w[i]) * mult
		w[i] = max(1, int(round(v)))  # keep positive integers
	return w

func _apply_bubble_visual(bubble: Node, value: int) -> void:
	if bubble is CanvasItem:
		var ci := bubble as CanvasItem
		match value:
			1: ci.modulate = Color(1, 1, 1, 1)       # normal
			2: ci.modulate = Color(0.85, 0.95, 1, 1) # faint blue
			3: ci.modulate = Color(0.40, 0.80, 1, 1) # bright blue
			5: ci.modulate = Color(1.00, 0.90, 0.40, 1) # golden
