class_name FishGachaButton
extends Button

@onready var fish_gacha_sprite: AnimatedSprite2D = %FishGachaSprite
@onready var follow: PathFollow2D = %Follow
@onready var pod: AnimatedSprite2D = %Pod
@onready var pods: AnimatedSprite2D = %Pods
@onready var knob: AnimatedSprite2D = %Knob

@export var cost_bubbles: int = 5
@export var path_duration: float = 1.5
@export var from_ratio: float = 0.0
@export var to_ratio: float = 1.0
@export var wait_for_spawn_anim: bool = false
@export var fish_pack_pool: Array[FishPackResource]
@export var a_cost: int = -5
@export var b_cost: int = -20
@export var c_cost: int = -175


var fish_selected_frames:SpriteFrames

var _tween: Tween
var _sv: bool = true
func _ready() -> void:
	
	pressed.connect(_on_pressed)
	Events.fish_pack_selected_signal.connect(_on_fish_pack_selected)

func _on_pressed() -> void:
	if Globals.current_bubble_count < cost_bubbles:
		return
		
	pods.play("Running")
	knob.set_visible(true)
	knob.play("Running")
	disabled = true
	Events.fish_pack_button()
	
func _on_fish_pack_selected(fish_pack: String) -> void:
	var fpr: FishPackResource
	var new_frames: SpriteFrames
	
	match fish_pack:
		"A":
			fpr = fish_pack_pool[0]
			if Globals.current_bubble_count < a_cost:
				return
			Events.bubble_count_changed(a_cost)
		"B":
			if Globals.current_bubble_count < b_cost:
				return
			fpr = fish_pack_pool[1]
			Events.bubble_count_changed(b_cost)
		"C":
			if Globals.current_bubble_count < c_cost:
				return
			fpr = fish_pack_pool[2]
			Events.bubble_count_changed(c_cost)
		_:
			return 
			
	## Step 1: grab all keys from the fish_pool dictionary
	var fish_keys: Array = fpr.fish_pool.keys()
	
	## Step 2: pick one key randomly
	var random_key: String = fish_keys.pick_random()
	
	## Step 3: fetch that fish’s frames
	new_frames = fpr.fish_pool[random_key]
	print("Selected Pack:", fish_pack, " | Random Fish:", random_key, " | Frames:", new_frames)

	pods.pause()
	knob.pause()
	knob.set_visible(false)
	fish_gacha_sprite.play("Spawn")
	pod.play("Spin")
	
	await _run_path(from_ratio, to_ratio, path_duration)
	
	pod.play("Transform")
	
	await pod.animation_finished
	
	Events.spawn_fish(new_frames)
	follow.progress_ratio = from_ratio
	disabled = false
	

func _run_path(from: float, to: float, dur: float) -> void:
	if _tween:
		_tween.kill()
	follow.loop = false
	follow.progress_ratio = from
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(follow, "progress_ratio", to, dur)
	await _tween.finished
	
func _notification(what):
	if what == NOTIFICATION_TRANSFORM_CHANGED and scale != Vector2.ONE:
		scale = Vector2.ONE
