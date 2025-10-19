extends HSlider
class_name SFXVolumeSlider

@export var bus_name: String = "SFX"
@export var min_db: float = -40.0
@export var max_db: float = 0.0
@export var save_key: String = "audio/sfx_volume"  # consider user:// cfg (see note below)
signal sfx_v_changed(v: float) # linear 0..1
@onready var sfx: SFX = %SFX

var _bus_index: int = -1
const _MUTE_EPS := 0.0001

func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.01

	_bus_index = AudioServer.get_bus_index(bus_name)
	if _bus_index == -1:
		push_warning("Audio bus '%s' not found; falling back to 'Master'." % bus_name)
		_bus_index = AudioServer.get_bus_index("Master")

	# Load saved linear value if present; else derive from current bus dB
	if ProjectSettings.has_setting(save_key):
		value = float(ProjectSettings.get_setting(save_key))
	else:
		var current_db := AudioServer.get_bus_volume_db(_bus_index)
		var lin = (current_db - min_db) / max(0.0001, (max_db - min_db))
		value = clamp(lin, 0.0, 1.0)

	_apply_volume(value)

	value_changed.connect(_on_value_changed)
	# Play a short preview when slider drag ends (Range has drag_ended(bool changed))
	drag_ended.connect(func(changed: bool):
		if changed:
			_preview_sfx()
	)

func _on_value_changed(v: float) -> void:
	emit_signal("sfx_v_changed", v)
	_apply_volume(v)
	ProjectSettings.set_setting(save_key, v)
	ProjectSettings.save()

func _apply_volume(v: float) -> void:
	if _bus_index == -1:
		return
	v = clamp(v, 0.0, 1.0)

	var mute := v <= _MUTE_EPS
	AudioServer.set_bus_mute(_bus_index, mute)
	if mute:
		return

	# Map linear 0..1 to [min_db..max_db] and apply
	var db = lerp(min_db, max_db, v)
	AudioServer.set_bus_volume_db(_bus_index, db)

func _preview_sfx() -> void:
	# Try to play a short SFX so the user hears the level
	if sfx == null:
		return
	if sfx is AudioStreamPlayer:
		var p := sfx as AudioStreamPlayer
		p.stop()
		p.play()
	elif sfx.has_method("play_ui_click"):
		sfx.call_deferred("play_ui_click")
	elif sfx.has_method("play_test"):
		sfx.call_deferred("play_test")
