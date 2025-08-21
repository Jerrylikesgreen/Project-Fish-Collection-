class_name FoodGacha extends AnimatedSprite2D


func _ready() -> void:
	Events.spawn_fish_food.connect(_on_food_spawn)


func _on_food_spawn()->void:
	play("Spawn")
