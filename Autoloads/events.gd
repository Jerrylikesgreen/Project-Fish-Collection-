extends Node

signal spawn_fish_food

signal player_message(new_message:String)

signal bubble_count_changed_signal(bubble_count:int)

signal spawn_fish_signal(base_frames: SpriteFrames, evo_frames: SpriteFrames, species_id: String, display_name: String)

signal fish_spawned(fish: Fish)  # emitted by your spawner AFTER instancing

signal fish_pack_button_pressed
signal fish_pack_selected_signal(pack: String)  # UI chose A/B/C
signal fish_rolled_signal(pack: String, species_id: String, frames: SpriteFrames)

signal selling_fish_signal(enabled:bool)

signal add_fish_to_collection_signal(fish:Fish)

signal _on_button_signal

signal collection_discover(species_id: String, display_name: String, icon: Texture2D)
signal collection_add(species_id: String)  # for increments when “caught”
signal play_sfx_signal(sfx: AudioStream)
signal game_started
signal global_sfx_signal(sfx: AudioStream)



var selling_fish := false
var _sv: int = 0
var _sv2: int = 0 
func spawn_food_button_pressed() -> void:
	emit_signal("spawn_fish_food") 

func spawn_fish(base_frames: SpriteFrames, species_id: String, display_name: String, evo_frames: SpriteFrames = null) -> void:
	# Emit with evo_frames (may be null if caller doesn’t provide it)
	emit_signal("spawn_fish_signal", base_frames, evo_frames, species_id, display_name)

	display_player_message("What did you get?")

	print("[Events] spawn_fish -> species=%s | base_frames=%s | evo_frames=%s | name=%s"
		% [species_id, str(base_frames), str(evo_frames), display_name])


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
		print(new_bubble_count)
		return
	Globals.current_bubble_count = new_bubble_count
	emit_signal("bubble_count_changed_signal", new_bubble_count)
	print("End")


func fish_pack_button()->void:
	emit_signal("fish_pack_button_pressed")
	

func fish_pack_selected(fish_pack: String)->void:
	emit_signal("fish_pack_selected_signal", fish_pack)
	display_player_message("You got a " + fish_pack  )
	
func sell_fish_button_pressed(value: bool) -> void:
	selling_fish = value
	emit_signal("selling_fish_signal", value)
	
func play_sfx(sfx: AudioStream)->void:
	emit_signal("play_sfx_signal", sfx)
	pass

func game_start()-> void:
	emit_signal("game_started")

func add_fish_to_collection(fish:Fish)->void:
	emit_signal("add_fish_to_collection_signal", fish)
