class_name Fish
extends Node2D

const BUBBLE := preload("res://Scenes/bubble.tscn")

@export var species_id: String = ""      # e.g. "Clownfish"
@export var display_name: String = ""    # e.g. "Clownfish"
@onready var fish_sprite: Fish_Sprite = %FishSprite
@onready var bubble_spawner: Timer = %BubbleSpawner
@onready var fish_body: FishBody = $FishBody
@onready var mouth: Marker2D = %Marker2D
@onready var sell_button: Button = %SellButton
@export var icon_override: Texture2D

@onready var anim: Fish_Sprite = %FishSprite

@export var spawn_every: float = 1.0

const RARITIES := ["Base","Gold","Green","Pink"]

@export_enum("Base","Gold","Green","Pink") var rarity: int:
	set(value):
		_rarity = clampi(value, 0, RARITIES.size() - 1)
		if is_inside_tree():
			_apply_rarity_to_sprite()
	get:
		return _rarity
var _rarity: int = 0

const RARITY_WEIGHTS := [55, 25, 15, 5]

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	sell_button.pressed.connect(_on_sell_button_pressed)
	_rng.randomize()
	Events.selling_fish_signal.connect(_on_selling_fish_signal)
	bubble_spawner.wait_time = spawn_every
	bubble_spawner.one_shot = false
	if not bubble_spawner.timeout.is_connected(self._spawn_one):
		bubble_spawner.timeout.connect(self._spawn_one)
	bubble_spawner.start()

	# pick weighted rarity, store to export (triggers sprite update via setter)
	rarity = _pick_random_rarity_index()
	print(rarity, " Fish")

func _spawn_one() -> void:
	var bubble: RigidBody2D = BUBBLE.instantiate()
	get_tree().current_scene.get_child(1).add_child(bubble)
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
	Events.bubble_count_changed(3)
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
