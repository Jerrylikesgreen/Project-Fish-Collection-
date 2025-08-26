extends TextureButton


var _hover := false
var _pressing := false

func _ready() -> void:
	pressed.connect(_on_left_click)


func _on_left_click() -> void:
	print("[CameraShotButton] Left-click → Screenshot")
	await _emit_action_once("Screenshot")
	call_deferred("release_focus") 

func _emit_action_once(action_name: String) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	Input.parse_input_event(press)

	await get_tree().process_frame

	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	Input.parse_input_event(release)
