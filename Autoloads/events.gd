extends Node

signal spawn_fish_food
signal player_message(new_message:String)
signal bubble_count_changed_signal(bubble_count:int)
signal spawn_fish_signal(new_frames:SpriteFrames)
signal fish_pack_button_pressed
signal fish_pack_selected_signal(fish_pack: String)


var _sv: int = 0
var _sv2: int = 0 
func spawn_food_button_pressed() -> void:
	emit_signal("spawn_fish_food")  # pass TRUE here!

func spawn_fish(new_frames:SpriteFrames):
	emit_signal("spawn_fish_signal", new_frames)
	display_player_message("What did you get?")

func display_player_message(new_message:String)-> void:
	emit_signal("player_message", new_message)
	if _sv2 > 2:
		emit_signal("player_message", "Boo!")
	if _sv2 > 5:
		emit_signal("player_message", "Ohhh! what a cute fish!")


func bubble_count_changed(bubble_count:int)->void:
	var new_bubble_count = Globals.current_bubble_count + bubble_count
	if new_bubble_count < 0 :
		if _sv > 3 :
			display_player_message("I said you neededed more Bubbles!")
			display_player_message("Pop the Bubbles!")
		display_player_message("You need more Bubbles!")
		_sv = 1 + _sv
		return
	Globals.current_bubble_count = new_bubble_count
	emit_signal("bubble_count_changed_signal", new_bubble_count)


func fish_pack_button()->void:
	emit_signal("fish_pack_button_pressed")
	

func fish_pack_selected(fish_pack: String)->void:
	emit_signal("fish_pack_selected_signal", fish_pack)
	display_player_message("You got a " + fish_pack  )
