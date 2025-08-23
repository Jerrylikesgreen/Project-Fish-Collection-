class_name FoodSpawner
extends Node2D

const FISH_FOOD := preload("res://Scenes/fish_food.tscn")

# Where to spawn (drag one or more Marker2D into this array in the inspector)
@export var spawn_markers: Array[Marker2D] = []

# Cost to drop food
@export var bubble_cost: int = 3

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
	Events.spawn_fish_food.connect(spawn_fish_food)

func spawn_fish_food() -> void:
	if Globals.current_bubble_count < 3:
		return
	Events.bubble_count_changed(-3)

	var pos := global_position  # or pick from markers if you have them

	var food := FISH_FOOD.instantiate()
	add_child(food)
	food.global_position = pos
	var r: int = (_rand_rarity() if random_rarity else rarity)

	_apply_rarity_frame(food, r)
	food._rarity = r

	var names := ["Common", "Uncommon", "Rare", "Ultra"]
	Events.display_player_message("You got " + names[clamp(r, 0, 3)])

	_pop_in(food, 0.16, 1.06)


# ---------- helpers ----------

func _pick_spawn_position() -> Vector2:
	if spawn_markers.size() > 0:
		var m = spawn_markers.pick_random()
		if m and is_instance_valid(m):
			return m.global_position
	return global_position

func _apply_rarity_frame(food: Node, r: int) -> void:
	# Works if the root is AnimatedSprite2D
	if food is AnimatedSprite2D:
		(food as AnimatedSprite2D).frame = r
		return
	# Otherwise try common child names/paths
	var spr := food.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null:
		# if your scene exposes a script var `fish_food_sprite`, use it:
		if "fish_food_sprite" in food:
			spr = food.fish_food_sprite
	if spr:
		spr.frame = r
	# else: silently ignore (no crash)

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

func _pop_in(node: Node, t: float = 0.2, overshoot: float = 1.08) -> void:
	var ci := node as CanvasItem
	if ci:
		ci.modulate.a = 0.0
	if "scale" in node:
		node.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	if ci:
		tw.set_parallel(true)
		tw.tween_property(ci, "modulate:a", 1.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
	tw.tween_property(node, "scale", Vector2(overshoot, overshoot), t)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
