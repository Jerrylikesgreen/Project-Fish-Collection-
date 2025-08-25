class_name FoodSpawner
extends Node2D

const FISH_FOOD := preload("res://Scenes/fish_food.tscn")

@export var spawn_marker: Marker2D
@export var bubble_cost: int = 5

@export_enum("Common", "Uncommon", "Rare", "Ultra") var rarity: int = 0
@export var random_rarity: bool = true

@export var weight_common:   int = 50
@export var weight_uncommon: int = 30
@export var weight_rare:     int = 15
@export var weight_ultra:    int = 5

# ---------- copy & cadence ----------
const LINES_COMMON := [
	"Dropped some flakes.",
	"Snack time.",
	"A quick nibble."
]
const LINES_UNCOMMON := [
	"Pellets on the way.",
	"A tastier snack lands."
]
const LINES_RARE := [
	"A rare treat splashes down.",
	"That should perk them up."
]
const LINES_ULTRA := [
	"Ultra treat—everyone swarms!",
	"That’s the good stuff."
]

func _ready() -> void:
	randomize()
	if "spawn_fish_food" in Events:
		Events.spawn_fish_food.connect(spawn_fish_food)
	else:
		push_warning("[FoodSpawner] Events.spawn_fish_food signal missing")

func spawn_fish_food() -> void:
	# Gate: not enough bubbles
	if Globals.current_bubble_count < bubble_cost:
		var short := bubble_cost - Globals.current_bubble_count
		# brief cooldown so holding the button doesn't spam
		Events.say_once("food_not_enough", "Need %d more bubbles for food." % short, "WARN", 2.0)
		return

	# Spend (Events will handle the spend message if you keep it enabled there)
	Events.bubble_count_changed(-bubble_cost)
	await get_tree().get_frame()

	# Spawn
	var pos := _spawn_pos()
	var food := FISH_FOOD.instantiate()
	add_child(food)
	food.global_position = pos

	var r: int = (_rand_rarity() if random_rarity else rarity)
	_apply_rarity_frame(food, r)
	food._rarity = r

	_announce_food(r)

# ---------- helpers ----------

func _announce_food(r: int) -> void:
	# Light touch for common/uncommon, always announce rare/ultra.
	match r:
		0:
			if randf() < 0.25:
				Events.say_once("food_common", LINES_COMMON.pick_random(), "ACTION", 5.0)
		1:
			if randf() < 0.40:
				Events.say_once("food_uncommon", LINES_UNCOMMON.pick_random(), "ACTION", 6.0)
		2:
			Events.say_once("food_rare", LINES_RARE.pick_random(), "SUCCESS", 8.0)
		3:
			Events.say_once("food_ultra", LINES_ULTRA.pick_random(), "SUCCESS", 12.0)
		_:
			pass

func _spawn_pos() -> Vector2:
	if spawn_marker and is_instance_valid(spawn_marker):
		return spawn_marker.global_position
	return global_position

func _apply_rarity_frame(food: Node, r: int) -> void:
	if food is AnimatedSprite2D:
		(food as AnimatedSprite2D).frame = r
		return
	var spr := food.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if spr == null and "fish_food_sprite" in food:
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
