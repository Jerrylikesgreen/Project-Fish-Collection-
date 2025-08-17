class_name Inventory_Button
extends Button

@onready var food_inventory: FoodInventory = %FoodInventory

func _ready() -> void:
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	food_inventory.visible = !food_inventory.visible
