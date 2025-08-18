class_name FishSpawner extends Node2D

const FISH = preload("res://Scenes/fish.tscn")

var fish_instance: Node2D

func _ready() -> void:
	Events.spawn_fish_signal.connect(_on_fish_spawn)
	

func _on_fish_spawn()->void:
	fish_instance = FISH.instantiate()
	add_child(fish_instance)
