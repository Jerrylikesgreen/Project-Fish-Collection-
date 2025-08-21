extends Node

signal spawn_fish_food
signal player_message(new_message:String)
signal bubble_count_changed_signal(bubble_count:int)
signal spawn_fish_signal



func spawn_food_button_pressed() -> void:
	emit_signal("spawn_fish_food")  # pass TRUE here!

func spawn_fish():
	emit_signal("spawn_fish_signal")

func display_player_message(new_message:String)-> void:
	emit_signal("player_message", new_message)

func bubble_count_changed(bubble_count:int)->void:
	var new_bubble_count = Globals.current_bubble_count + bubble_count
	Globals.current_bubble_count = new_bubble_count
	emit_signal("bubble_count_changed_signal", new_bubble_count)
	pass
