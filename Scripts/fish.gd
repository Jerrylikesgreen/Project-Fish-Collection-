class_name Fish
extends Node2D

const BUBBLE := preload("res://Scenes/bubble.tscn")

@onready var fish_sprite: Fish_Sprite = %FishSprite
@onready var bubble_spawner: Timer = %BubbleSpawner
@onready var fish_body: FishBody = $FishBody
@onready var mouth: Marker2D = %Marker2D

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
	_rng.randomize()

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
