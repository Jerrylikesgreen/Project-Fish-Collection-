extends HSlider
class_name SFXVolumeSlider

@export var bus_name: String = "SFX"

@export var min_db: float = -40.0
@export var max_db: float = 0.0

@export var save_key: String = "audio/sfx_volume"

signal sfx_v_changed(v: float) # linear 0..1

var _bus_index: int = -1

func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.01

	_bus_index = AudioServer.get_bus_index(bus_name)
	if _bus_index == -1:
		push_warning("Audio bus '%s' not found; falling back to 'Master'." % bus_name)
		_bus_index = AudioServer.get_bus_index("Master")

	if ProjectSettings.has_setting(save_key):
		value = float(ProjectSettings.get_setting(save_key))

	_apply_volume(value)

	value_changed.connect(_on_value_changed)

func _on_value_changed(v: float) -> void:
	emit_signal("sfx_v_changed", v)
	_apply_volume(v)

	ProjectSettings.set_setting(save_key, v)
	ProjectSettings.save()

func _apply_volume(v: float) -> void:
	if _bus_index == -1:
		return

	var db = lerp(min_db, max_db, clamp(v, 0.0, 1.0))
