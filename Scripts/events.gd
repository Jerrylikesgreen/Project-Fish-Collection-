extends Node

signal spawn_food_mode(bool)
signal player_message(new_message:String)
signal food_gatcha(_is_feed_mode: bool)
signal bubble_count_changed_signal(bubble_count:int)
signal spawn_fish_signal



func spawn_food_button_pressed() -> void:
	emit_signal("spawn_food_mode", true)  # pass TRUE here!

	
func food_gatcha_signal(_is_feed_mode):
	emit_signal("food_gatcha", _is_feed_mode)
	print("Emits")

func spawn_fish():
	emit_signal("spawn_fish_signal")

func display_player_message(new_message:String)-> void:
	emit_signal("player_message", new_message)

func bubble_count_changed(bubble_count:int)->void:
	var new_bubble_count = Globals.current_bubble_count + bubble_count
	Globals.current_bubble_count = new_bubble_count
	emit_signal("bubble_count_changed_signal", new_bubble_count)
	pass
