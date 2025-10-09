class_name BGM
extends AudioStreamPlayer

# ─── OPTIONS ─────────────────────────────────────────────
@export var fade_enabled  : bool  = true
@export var fade_in_time  : float = 1.0
@export var fade_out_time : float = 1.0

enum Track { PINK_BLOOM }
const TRACK_NONE := -1  # sentinel for "no track"

@export var fade_time     : float = 0.08  # short glide for slider moves
# Use int for storage so we can represent TRACK_NONE
var _current_track       : int = TRACK_NONE
var _last_gameplay_track : int = TRACK_NONE
var _tw                  : Tween = null


@onready var bgm_volume_slider: BGMVolumeSlider = %BGMVolumeSlider

const MUTE_DB := -80.0
const MIN_LINEAR := 0.0001

var _bus_idx: int = -1
var _tw_node: Tween    = null  # for node volume fades (track x-fades)
var _tw_bus:  Tween    = null  # for bus volume fades (slider moves)

func _ready() -> void:
	bus = "BGM"
	_bus_idx = AudioServer.get_bus_index("BGM")
	if _bus_idx < 0:
		push_warning("Audio bus 'BGM' not found; falling back to Master.")
		_bus_idx = AudioServer.get_bus_index("Master")

	bgm_volume_slider.value_changed.connect(_on_volume_changed)
	Events.game_started.connect(_on_game_start)
	_on_volume_changed(bgm_volume_slider.value)
	play()


func set_fade_enabled(enabled: bool) -> void:
	fade_enabled = enabled

func play_track(track: int, custom_time: float = -1.0) -> void:
	if track == _current_track:
		return

	var use_custom: bool = custom_time >= 0.0
	var out_t: float = (custom_time if use_custom else fade_out_time)
	var in_t : float = (custom_time if use_custom else fade_in_time)

	_kill_tween_node()

	if playing:
		_fade_out_then_switch(track, out_t, in_t)
	else:
		_switch_stream(track)
		_fade_in(in_t)


func _on_fade_out_finished(next_track: int, in_t: float) -> void:
	stop()
	_switch_stream(next_track)
	_fade_in(in_t)

func _fade_out_then_switch(next_track: int, out_t: float, in_t: float) -> void:
	if not fade_enabled or out_t <= 0.0:
		stop()
		_switch_stream(next_track)
		_fade_in(in_t)
		return

	_kill_tween_node()
	_tw_node = get_tree().create_tween()
	_tw_node.tween_property(self, "volume_db", MUTE_DB, out_t)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tw_node.tween_callback(Callable(self, "_on_fade_out_finished").bind(next_track, in_t))

func _fade_in(t: float) -> void:
	if not fade_enabled or t <= 0.0:
		volume_db = 0.0
		play()
		return

	var start_db = clamp(volume_db, MUTE_DB, 0.0)
	if not playing:
		volume_db = start_db if start_db <= 0.0 else -30.0
		play()

	_kill_tween_node()
	_tw_node = get_tree().create_tween()
	_tw_node.tween_property(self, "volume_db", 0.0, t)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


	# Start from current volume (in case we were mid-fade)
	start_db = clamp(volume_db, -80.0, 0.0)
	if not playing:
		volume_db = start_db if start_db <= 0.0 else -30.0
		play()

	_kill_tween_node()
	var tw: Tween = get_tree().create_tween()
	_tw = tw
	tw.tween_property(self, "volume_db", 0.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _switch_stream(track: int) -> void:
	_current_track = track

func _kill_tween_node() -> void:
	if is_instance_valid(_tw_node):
		_tw_node.kill()
	_tw_node = null

func _kill_tween_bus() -> void:
	if is_instance_valid(_tw_bus):
		_tw_bus.kill()
	_tw_bus = null


# Signals
func _on_evolve(new_track: int) -> void:
	_last_gameplay_track = new_track
	play_track(new_track)

func _on_game_start() -> void:
	if _last_gameplay_track != TRACK_NONE:
		play_track(_last_gameplay_track, 0.2)
	else:
		play_track(Track.PINK_BLOOM, 0.2)

func _on_volume_changed(v: float) -> void:
	v = clamp(v, 0.0, 1.0)
	var mute := v <= 0.0001
	AudioServer.set_bus_mute(2, mute)
	stream_paused = mute

	if mute:
		if _tw: _tw.kill()
		return

	var target_db := linear_to_db(v)
	if fade_enabled:
		_fade_bus_to(target_db, fade_time)
	else:
		AudioServer.set_bus_volume_db(2, target_db)

func _fade_bus_to(target_db: float, t: float) -> void:
	if _tw: _tw.kill()
	var start_db := AudioServer.get_bus_volume_db(2)
	_tw = create_tween()
	_tw.tween_method(
		func(db): AudioServer.set_bus_volume_db(2, db),
		start_db, target_db, max(t, 0.01))
