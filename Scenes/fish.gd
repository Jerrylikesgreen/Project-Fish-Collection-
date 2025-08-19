class_name Fish
extends Node2D

const BUBBLE := preload("res://Scenes/bubble.tscn")

@onready var bubble_spawner: Timer = %BubbleSpawner

@export var spawn_every: float = 1.0
@onready var mouth: Marker2D = %Marker2D

func _ready() -> void:
	bubble_spawner.wait_time = spawn_every
	bubble_spawner.one_shot = false

	if not bubble_spawner.timeout.is_connected(_spawn_one):
		bubble_spawner.timeout.connect(_spawn_one)

	bubble_spawner.start()

func _spawn_one() -> void:
	var bubble: AnimatedSprite2D = BUBBLE.instantiate()
	get_tree().current_scene.add_child(bubble)
	bubble.global_position = mouth.global_position
