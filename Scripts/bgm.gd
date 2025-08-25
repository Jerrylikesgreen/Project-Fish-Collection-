class_name BGM
extends AudioStreamPlayer

# ─── OPTIONS ─────────────────────────────────────────────
@export var fade_enabled  : bool  = true
@export var fade_in_time  : float = 1.0
@export var fade_out_time : float = 1.0

enum Track { PINK_BLOOM }
const TRACK_NONE := -1  # sentinel for "no track"

# Use int for storage so we can represent TRACK_NONE
var _current_track       : int = TRACK_NONE
var _last_gameplay_track : int = TRACK_NONE
var _tw                  : Tween = null


func _ready() -> void:

	Events.game_started.connect(_on_game_start)


func set_fade_enabled(enabled: bool) -> void:
	fade_enabled = enabled

func play_track(track: int, custom_time: float = -1.0) -> void:
	if track == _current_track:
		return

	var use_custom: bool = custom_time >= 0.0
	var out_t: float = (custom_time if use_custom else fade_out_time)
	var in_t : float = (custom_time if use_custom else fade_in_time)

	_kill_tween()

	if playing:
		_fade_out_then_switch(track, out_t, in_t)
	else:
		_switch_stream(track)
		_fade_in(in_t)

# Internal
func _fade_out_then_switch(next_track: int, out_t: float, in_t: float) -> void:
	if not fade_enabled or out_t <= 0.0:
		stop()
		_switch_stream(next_track)
		_fade_in(in_t)
		return

	var tw: Tween = get_tree().create_tween()
	_tw = tw
	tw.tween_property(self, "volume_db", -80.0, out_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(Callable(self, "_on_fade_out_finished").bind(next_track, in_t))

func _on_fade_out_finished(next_track: int, in_t: float) -> void:
	stop()
	_switch_stream(next_track)
	_fade_in(in_t)

func _fade_in(t: float) -> void:
	if not fade_enabled or t <= 0.0:
		volume_db = 0.0
		play()
		return

	# Start from current volume (in case we were mid-fade)
	var start_db: float = clamp(volume_db, -80.0, 0.0)
	if not playing:
		volume_db = start_db if start_db <= 0.0 else -30.0
		play()

	_kill_tween()
	var tw: Tween = get_tree().create_tween()
	_tw = tw
	tw.tween_property(self, "volume_db", 0.0, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _switch_stream(track: int) -> void:
	_current_track = track

func _kill_tween() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = null

# Signals
func _on_evolve(new_track: int) -> void:
	_last_gameplay_track = new_track
	play_track(new_track)

func _on_game_start() -> void:
	if _last_gameplay_track != TRACK_NONE:
		play_track(_last_gameplay_track, 0.2)
	else:
		play_track(Track.PINK_BLOOM, 0.2)
