class_name FoodSpawner
extends Node2D

const FISH_FOOD := preload("res://Scenes/fish_food.tscn")


@onready var food_spawner: FoodSpawner = %FoodSpawner

func _ready() -> void:
	Events.spawn_fish_food.connect(spawn_fish_food)

func spawn_fish_food() -> void:

	var marker = food_spawner
	var pos = marker.global_position

	var food := FISH_FOOD.instantiate()
	add_child(food)
	food.global_position = pos
	Events.bubble_count_changed(-3)
