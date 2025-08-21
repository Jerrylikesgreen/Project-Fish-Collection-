class_name BubbleSprite
extends AnimatedSprite2D





func _ready() -> void:
	animation_finished.connect(_on_animation_finished)




func _on_animation_finished() -> void:
	print("Free")
	
	get_parent().queue_free()
