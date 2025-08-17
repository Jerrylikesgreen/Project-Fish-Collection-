class_name FoodInventory
extends ItemList

@onready var food: food_button = %Food

var inventory: Dictionary = {}

const RARITIES := [
	"Common", "Uncommon", "Rare", "Epic", "Legendary"
]

func _ready() -> void:
	randomize()
	food.pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	add_item_to_inventory("Food")

func add_item_to_inventory(base_name: String) -> void:
	var rarity := get_random_rarity()
	var full_name := "%s (%s)" % [base_name, rarity]

	if inventory.has(full_name):
		inventory[full_name] += 1
	else:
		inventory[full_name] = 1

	_refresh_list()

func _refresh_list() -> void:
	clear()
	for item_name in inventory.keys():
		var count = inventory[item_name]
		add_item(item_name + " x" + str(count))

func get_random_rarity() -> String:
	var roll := randi_range(1, 100)

	if roll <= 50:
		return "Common"
	elif roll <= 75:
		return "Uncommon"
	elif roll <= 90:
		return "Rare"
	elif roll <= 98:
		return "Epic"
	else:
		return "Legendary"



func has_food_available() -> bool:
	for key in inventory.keys():
		if inventory[key] > 0:
			return true
	return false

func consume_food() -> void:
	for key in inventory.keys():
		if inventory[key] > 0:
			inventory[key] -= 1
			if inventory[key] == 0:
				inventory.erase(key)
			_refresh_list()
			break
