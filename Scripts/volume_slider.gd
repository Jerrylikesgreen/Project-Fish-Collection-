extends HSlider
class_name BGMVolumeSlider

signal volume_changed(v: float)

func _ready():
	connect("value_changed",_on_value_changed)

func _on_value_changed(value: float) -> void:
	emit_signal("volume_changed", value)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
