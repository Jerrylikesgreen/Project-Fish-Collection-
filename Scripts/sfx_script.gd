class_name SFX extends AudioStreamPlayer


const BLOOP = preload("res://Assets/OGG/bloop.wav")
const POP = preload("res://Assets/OGG/pop1.mp3")

@export var sfx_pool: Array[AudioStream]

func _ready() -> void:
	Events.global_sfx_signal.connect(_on_signal)
	Events._on_button_signal.connect(_on_button_signal)
	

func _on_signal(v:int)->void:
	var sfx = sfx_pool[v]
	set_stream(sfx)
	play()

func _on_button_signal() ->void:
	play()
