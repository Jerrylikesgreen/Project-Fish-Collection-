extends Node

signal spawn_food_mode(bool)
signal player_message(new_message:String)
signal food_gatcha

func spawn_food_button_pressed() -> void:
	emit_signal("spawn_food_mode", true)  # pass TRUE here!

	
func food_gatcha_signal():
	emit_signal("food_gatcha")


func display_player_message(new_message:String)-> void:
	emit_signal("player_message", new_message)
