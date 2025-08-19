class_name Bubble
extends AnimatedSprite2D


@export var bubble_value: int = 1
@onready var area_2d: Area2D = %Area2D
var _popping := false  # guard so we only pop once

func _ready() -> void:
	area_2d.input_event.connect(_on_pop_input)
	animation_finished.connect(_on_animation_finished)


func _on_pop_input(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if _popping:
		return
	if event.is_action_pressed("Tap"):
		_popping = true
		play("Pop")
		area_2d.input_pickable = false
		print("Pop")
		Events.bubble_count_changed(bubble_value)

func _on_animation_finished() -> void:
	print("Free")
	queue_free()
