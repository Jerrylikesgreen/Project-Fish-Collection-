class_name FoodSpawner
extends Node
const FISH_FOOD = preload("res://Scenes/fish_food.tscn")

@onready var inventory: FoodInventory = %FoodInventory

var _can_spawn: bool = false

func _ready() -> void:
	Events.spawn_food_mode.connect(_on_spawn_mode_signal)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Tap") and _can_spawn:
		spawn_fish_food()
		print("Spawned from input event")

func spawn_fish_food() -> void:
	if not inventory.has_food_available():
		Events.display_player_message("You're out of food!")
		return

	# Spawn the apple
	var new_fish_food = FISH_FOOD.instantiate()
	get_parent().add_child(new_fish_food)
	new_fish_food.global_position = get_viewport().get_mouse_position()

	# Remove one food item
	inventory.consume_food()


func _on_spawn_mode_signal(value: bool) -> void:
	_can_spawn = value
