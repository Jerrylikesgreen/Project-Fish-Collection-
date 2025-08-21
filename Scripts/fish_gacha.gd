class_name FishGachaButton
extends Button

@onready var fish_gacha_sprite: AnimatedSprite2D = %FishGachaSprite
@onready var follow: PathFollow2D = %Follow
@onready var pod: AnimatedSprite2D = %Pod

@export var cost_bubbles: int = 5
@export var path_duration: float = 1.5
@export var from_ratio: float = 0.0
@export var to_ratio: float = 1.0
@export var wait_for_spawn_anim: bool = false

var _tween: Tween

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if Globals.current_bubble_count < cost_bubbles:
		return

	disabled = true
	Events.bubble_count_changed(-cost_bubbles)
	fish_gacha_sprite.play("Spawn")
	pod.play("Spin")
	await _run_path(from_ratio, to_ratio, path_duration)
	pod.play("Transform")
	await pod.animation_finished
	Events.spawn_fish()
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
