class_name FoodSpawner
extends Node2D

const FISH_FOOD := preload("res://Scenes/fish_food.tscn")

# Single, fixed spawn point (set this in the Inspector). If left empty, we use this node's position.
@export var spawn_marker: Marker2D

# Cost to drop food
@export var bubble_cost: int = 5

# Inspector default rarity (used if random_rarity = false)
@export_enum("Common", "Uncommon", "Rare", "Ultra") var rarity: int = 0
@export var random_rarity: bool = true

# Weights for random rarity (relative)
@export var weight_common:   int = 50
@export var weight_uncommon: int = 30
@export var weight_rare:     int = 15
@export var weight_ultra:    int = 5

func _ready() -> void:
	randomize()
	if "spawn_fish_food" in Events:
		Events.spawn_fish_food.connect(spawn_fish_food)
	else:
		push_warning("[FoodSpawner] Events.spawn_fish_food signal missing")

func spawn_fish_food() -> void:
	if Globals.current_bubble_count < bubble_cost:
		print("[FoodSpawner] Not enough bubbles (have=%d need=%d)" % [Globals.current_bubble_count, bubble_cost])
		return

	Events.bubble_count_changed(-bubble_cost)

	var pos := _spawn_pos()  # <- deterministic
	var food := FISH_FOOD.instantiate()
	add_child(food)
	food.global_position = pos

	var r: int = (_rand_rarity() if random_rarity else rarity)
	_apply_rarity_frame(food, r)
	food._rarity = r

	var names := ["Common", "Uncommon", "Rare", "Ultra"]
	Events.display_player_message("You got a " + names[clamp(r, 0, 3)])


# ---------- helpers ----------

func _spawn_pos() -> Vector2:
	if spawn_marker and is_instance_valid(spawn_marker):
		return spawn_marker.global_position
	return global_position

func _apply_rarity_frame(food: Node, r: int) -> void:
	# Works if the root is AnimatedSprite2D
	if food is AnimatedSprite2D:
		(food as AnimatedSprite2D).frame = r
		return
	# Otherwise try common child names/paths
	var spr := food.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null:
		spr = food.fish_food_sprite
	if spr:
		spr.frame = r

func _rand_rarity() -> int:
	var weights := [max(0, weight_common), max(0, weight_uncommon), max(0, weight_rare), max(0, weight_ultra)]
	var total = weights[0] + weights[1] + weights[2] + weights[3]
	if total <= 0:
		return 0
	var pick = randi() % total
	var acc := 0
	for i in weights.size():
		acc += weights[i]
		if pick < acc:
			return i
	return 0
