class_name food_button
extends Button

@export var food_cost: int
@onready var food_gacha_sprite: AnimatedSprite2D = $FoodGachaSprite

func _ready() -> void:
	food_cost = Globals.food_cost
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	if Globals.current_bubble_count < food_cost:
		return
	Events.spawn_food_button_pressed()
