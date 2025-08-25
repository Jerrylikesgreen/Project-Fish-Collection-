extends Node

# ───── Signals ─────────────────────────────────────────────────────────────────
signal spawn_fish_food
signal player_message(new_message: String)
signal bubble_count_changed_signal(bubble_count: int)
signal spawn_fish_signal(base_frames: SpriteFrames, evo_frames: SpriteFrames, species_id: String, display_name: String)
signal fish_spawned(fish: Fish)
signal fish_sold_signal
signal fish_pack_button_pressed
signal fish_pack_selected_signal(pack: String)
signal fish_rolled_signal(pack: String, species_id: String, frames: SpriteFrames)
signal selling_fish_signal(enabled: bool)
signal add_fish_to_collection_signal(fish: Fish)
signal setting_button_pressed_signal
signal _on_button_signal
signal collection_discover(species_id: String, display_name: String, icon: Texture2D)
signal collection_add(species_id: String)
signal play_sfx_signal(sfx: AudioStream)
signal game_started
signal global_sfx_signal(sfx: AudioStream)
signal open_collections_screen(enabled: bool)
signal update_ui
signal upgrade
# ───── Message throttle config ─────────────────────────────────────────
const MSG_MIN_GAP := 0.9            # seconds between visible messages
const MSG_WINDOW := 3.0             # burst window size (seconds)
const MSG_PER_WINDOW := 3           # max messages shown per window
const MSG_SAME_TEXT_COOLDOWN := 8.0 # suppress same text within this many seconds
const MSG_SHOW_BUBBLE_TOTAL := false

const MSG_TAG_MIN_GAP := {
	"UI": 0.6,
	"ACTION": 0.6,
	"WARN": 1.0,
	"SUCCESS": 1.0,
	"START": 9999.0,   # "Welcome!" basically once
	"COLLECT": 2.0,
	"SPAWN": 3.0,
}

# ───── Message throttle state ──────────────────────────────────────────
var _msg_queue: Array = []                       # [{text, tag}]
var _msg_last_emit_time: float = -9999.0
var _msg_last_by_tag := {}                       # tag -> last time
var _msg_recent_text_until := {}                 # text -> expire time
var _msg_window_count := 0
var _msg_tick: Timer = null
var _msg_window_timer: Timer = null
var _last_emit_norm := ""
var _last_emit_time := 0.0

# Optional per-text cooldowns (keys are *normalized*; see _normalize_key)
const MSG_TEXT_COOLDOWN := {
	"if your fish is sad, you need to feed it!": 99999.0
}

const BUBBLE_BATCH_WINDOW_DEFAULT := 0.6        # seconds to coalesce gains
const BUBBLE_GAIN_ANNOUNCE_THRESHOLD_DEFAULT := 5
const BUBBLE_PRINT_VERBOSITY_DEFAULT := 1       # 0=silent, 1=summary, 2=verbose

var _bubble_batch_window: float = BUBBLE_BATCH_WINDOW_DEFAULT
var _bubble_gain_announce_threshold: int = BUBBLE_GAIN_ANNOUNCE_THRESHOLD_DEFAULT
var _bubble_print_verbosity: int = BUBBLE_PRINT_VERBOSITY_DEFAULT

var _bubble_batch_accum: int = 0
var _bubble_batch_timer: Timer = null



# ───── State ───────────────────────────────────────────────────────────────────
var selling_fish := false
var _sv: int = 0
var _sv2: int = 0

# --- style handoff for next spawned fish ---
var next_fish_tint: Color = Color(1,1,1,1)
var next_fish_have_style: bool = false
var next_fish_sparkle: bool = false



func _ready() -> void:
	# Optional: allow tuning via ProjectSettings (Project > Project Settings > General)
	if ProjectSettings.has_setting("events/bubbles/batch_window"):
		_bubble_batch_window = float(ProjectSettings.get_setting("events/bubbles/batch_window"))
	if ProjectSettings.has_setting("events/bubbles/gain_announce_threshold"):
		_bubble_gain_announce_threshold = int(ProjectSettings.get_setting("events/bubbles/gain_announce_threshold"))
	if ProjectSettings.has_setting("events/bubbles/print_verbosity"):
		_bubble_print_verbosity = int(ProjectSettings.get_setting("events/bubbles/print_verbosity"))

	if _bubble_batch_timer == null:
		_bubble_batch_timer = Timer.new()
		_bubble_batch_timer.one_shot = true
		_bubble_batch_timer.wait_time = _bubble_batch_window
		add_child(_bubble_batch_timer)
		_bubble_batch_timer.timeout.connect(_flush_bubble_batch)
		# Message pump (drains queue at a controlled pace)
	_msg_tick = Timer.new()
	_msg_tick.one_shot = true
	_msg_tick.wait_time = 0.15
	add_child(_msg_tick)
	_msg_tick.timeout.connect(_pump_messages)
	
	# Burst window reset
	_msg_window_timer = Timer.new()
	_msg_window_timer.one_shot = false
	_msg_window_timer.wait_time = MSG_WINDOW
	add_child(_msg_window_timer)
	_msg_window_timer.timeout.connect(func():
		_msg_window_count = 0
	)
	_msg_window_timer.start()
	



var _msg_default_cooldown := 30.0           # seconds; change as you like
var _msg_last_until: Dictionary = {}        # text -> show-again time (unix seconds)

func _now_s() -> float:
	return Time.get_unix_time_from_system()

func display_player_message(new_message: String, cooldown: float = -1.0) -> void:
	# Deduplicate identical messages for a cooldown window
	var cd := (cooldown if cooldown >= 0.0 else _msg_default_cooldown)
	var n := _now_s()
	var allow_at := float(_msg_last_until.get(new_message, 0.0))
	if n < allow_at:
		# Suppress spam
		if _bubble_print_verbosity >= 2:
			print("[EVENTS:MSG] (suppressed) ", new_message)
		return

	_msg_last_until[new_message] = n + cd
	emit_signal("player_message", new_message)
	print("[EVENTS:MSG] %s" % new_message)


func _say(msg: String, tag: String = "INFO") -> void:
	_queue_msg(msg, tag)


func _log(fmt: String, args := []) -> void:
	if (args is Array) and (args.size() > 0):
		print("[EVENTS] " + fmt % args)
	else:
		print("[EVENTS] " + fmt)

func _fmt_bubbles() -> String:
	return "%d bubbles" % Globals.current_bubble_count

func _fmt_tank() -> String:
	return "%d/%d fish" % [Globals.current_number_of_fish_in_tank, Globals.max_fish_count]

func fish_pack_button_quiet() -> void:
	_log("fish_pack_button_quiet -> emit fish_pack_button_pressed")
	emit_signal("fish_pack_button_pressed")
	# No _say() here on purpose.


# ───── Button / simple emitters ────────────────────────────────────────────────
func spawn_food_button_pressed() -> void:
	_log("spawn_food_button_pressed -> emit spawn_fish_food")
	emit_signal("spawn_fish_food")
	

func fish_pack_button() -> void:
	_log("fish_pack_button -> emit fish_pack_button_pressed")
	emit_signal("fish_pack_button_pressed")
	_say("Pick a pack: A, B, or C!", "UI")

func fish_pack_selected(fish_pack: String) -> void:
	_log("fish_pack_selected -> '%s'" % fish_pack)
	emit_signal("fish_pack_selected_signal", fish_pack)
	_say("Pack %s selected!" % fish_pack, "UI")

func sell_fish_button_pressed(value: bool) -> void:
	selling_fish = value
	emit_signal("selling_fish_signal", value)
	_log("sell_fish_button_pressed -> selling_fish=%s" % str(value))
	var mode := "OFF"
	if value == true:
		mode = "ON"
	_say("Selling mode: " + mode, "UI")

func play_sfx(sfx: AudioStream) -> void:
	emit_signal("play_sfx_signal", sfx)
	_log("play_sfx -> %s" % str(sfx))

func game_start() -> void:
	emit_signal("game_started")
	_log("game_start emitted")
	_say("Welcome! Let's catch some fish!", "START")

func add_fish_to_collection(fish: Fish) -> void:
	emit_signal("add_fish_to_collection_signal", fish)
	var name := "Unknown"
	if fish != null:
		if fish.has_method("get_collection_name"):
			name = fish.get_collection_name()
	_log("add_fish_to_collection -> %s" % name)
	_say("Added to Collection: " + name, "COLLECT")

func fish_sold() -> void:
	emit_signal("fish_sold_signal")
	_log("fish_sold emitted")
	_say("Sold a fish. +3 bubbles!", "SELL")

func _on_settings_button_pressed() -> void:
	emit_signal("setting_button_pressed_signal")
	_log("_on_settings_button_pressed emitted")
	_say("Settings opened.", "UI")

# ───── Core logic ──────────────────────────────────────────────────────────────
func upgrade_button_pressed() -> void:
	const CAP_FISH := 12
	const CAP_COST := 501

	_log("upgrade_button_pressed | tank=%s | cost=%d | bubbles=%d",
		[_fmt_tank(), Globals.tank_cost, Globals.current_bubble_count])

	if (Globals.max_fish_count >= CAP_FISH) or (Globals.tank_cost >= CAP_COST):
		_say("No more upgrades. (Max capacity or price cap reached.)", "WARN")
		_log("Blocked: caps reached (max_fish=%d, tank_cost=%d)", [Globals.max_fish_count, Globals.tank_cost])
		return

	var missing_fish := Globals.max_fish_count - Globals.current_number_of_fish_in_tank
	if missing_fish < 0:
		missing_fish = 0
	var missing_bubbles := Globals.tank_cost - Globals.current_bubble_count
	if missing_bubbles < 0:
		missing_bubbles = 0

	if (missing_fish > 0) and (missing_bubbles > 0):
		_say("Need %d more fish and %d more bubbles." % [missing_fish, missing_bubbles], "WARN")
		_log("Blocked: missing fish=%d, bubbles=%d", [missing_fish, missing_bubbles])
		return
	if missing_fish > 0:
		_say("Need %d more fish in the tank." % missing_fish, "WARN")
		_log("Blocked: missing fish=%d", [missing_fish])
		return
	if missing_bubbles > 0:
		_say("Need %d more bubbles." % missing_bubbles, "WARN")
		_log("Blocked: missing bubbles=%d", [missing_bubbles])
		return

	var old_cap := Globals.max_fish_count
	var old_cost := Globals.tank_cost

	_log("Upgrade OK -> deduct cost=%d", [old_cost])
	bubble_count_changed(-old_cost)

	var new_cap := old_cap * 2
	var new_cost := old_cost * 10

	Globals.max_fish_count = new_cap
	Globals.tank_cost = new_cost
	emit_signal("update_ui")
	_say("Tank upgraded! Capacity: %d → %d. Next cost: %d bubbles." % [old_cap, new_cap, new_cost], "SUCCESS")
	_log("Upgrade: cap %d->%d | cost %d->%d | bubbles now=%d",
		[old_cap, new_cap, old_cost, new_cost, Globals.current_bubble_count])

func spawn_fish(base_frames: SpriteFrames, species_id: String, display_name: String, evo_frames: SpriteFrames = null) -> void:
	emit_signal("spawn_fish_signal", base_frames, evo_frames, species_id, display_name)

	Globals.current_number_of_fish_in_tank += 1

	display_player_message("A mysterious pod dropped into the tank.")

	print("[EVENTS:SPAWN] species='", species_id, "' name='", display_name,
		"' base=", str(base_frames), " evo=", str(evo_frames),
		" tank=", str(Globals.current_number_of_fish_in_tank), "/", str(Globals.max_fish_count))


	_sv2 += 1
	if _sv2 == 3:
		emit_signal("player_message", "Boo!")
		print("[EVENTS:MSG] Boo!")
	elif _sv2 == 6:
		emit_signal("player_message", "Ohhh! What a cute fish!")
		print("[EVENTS:MSG] Ohhh! What a cute fish!")

func bubble_count_changed(bubble_count: int) -> void:
	var before := Globals.current_bubble_count
	var after := before + bubble_count

	if _bubble_print_verbosity >= 2:
		print("[EVENTS] bubble_count_changed(", bubble_count, ") | before=", before, " -> after=", after)

	# Block spends that would go negative
	if after < 0:
		var short := -after
		display_player_message("You need " + str(short) + " more bubbles!")
		_sv += 1
		if _sv == 2:
			display_player_message("Try popping more bubbles first!")
		elif _sv == 4:
			display_player_message("You can earn bubbles by selling fish.")
		if _bubble_print_verbosity >= 1:
			print("[EVENTS] spend blocked: short by ", short, " (have=", before, ", delta=", bubble_count, ")")
		return

	# Apply total and notify UI
	Globals.current_bubble_count = after
	emit_signal("bubble_count_changed_signal", after)

	if bubble_count > 0:
		# Gains: batch and debounce
		_bubble_batch_accum += bubble_count
		if _bubble_print_verbosity >= 2:
			print("[EVENTS] gain batched: +", bubble_count, " (pending batch=", _bubble_batch_accum, ", total=", after, ")")

		if _bubble_batch_timer != null:
			_bubble_batch_timer.stop()
			_bubble_batch_timer.wait_time = _bubble_batch_window
			_bubble_batch_timer.start()

	elif bubble_count < 0:
		# Spend: flush any pending gain message, then announce immediately
		_flush_bubble_batch()
		var suffix := (" (%s total)" % str(Globals.current_bubble_count)) if MSG_SHOW_BUBBLE_TOTAL else ""
		display_player_message("Spent %d bubbles.%s" % [-bubble_count, suffix])


		if _bubble_print_verbosity >= 1:
			print("[EVENTS] spent ", -bubble_count, " -> total=", Globals.current_bubble_count)
	else:
		# No change
		pass


func _flush_bubble_batch() -> void:
	if _bubble_batch_accum <= 0:
		return

	if _bubble_batch_accum >= _bubble_gain_announce_threshold:
		var suffix := (" (%s total)" % str(Globals.current_bubble_count)) if MSG_SHOW_BUBBLE_TOTAL else ""
		display_player_message("+%d bubbles!%s" % [_bubble_batch_accum, suffix])

		if _bubble_print_verbosity >= 1:
			print("[EVENTS] flushed bubble batch: +", _bubble_batch_accum, " -> total=", Globals.current_bubble_count)
	else:
		if _bubble_print_verbosity >= 2:
			print("[EVENTS] silent flush: +", _bubble_batch_accum, " below threshold; total=", Globals.current_bubble_count)

	_bubble_batch_accum = 0


func configure_bubble_batch(window: float, threshold: int, verbosity: int) -> void:
	if window > 0.0:
		_bubble_batch_window = window
		if _bubble_batch_timer != null:
			_bubble_batch_timer.wait_time = _bubble_batch_window
	if threshold >= 0:
		_bubble_gain_announce_threshold = threshold
	if verbosity >= 0:
		_bubble_print_verbosity = verbosity

func set_bubble_batch_window(window: float) -> void:
	if window > 0.0:
		_bubble_batch_window = window
		if _bubble_batch_timer != null:
			_bubble_batch_timer.wait_time = _bubble_batch_window

func set_bubble_gain_announce_threshold(value: int) -> void:
	if value >= 0:
		_bubble_gain_announce_threshold = value

func set_bubble_print_verbosity(value: int) -> void:
	if value >= 0:
		_bubble_print_verbosity = value



func _consume_next_fish_style() -> Dictionary:
	# Returns and clears the pending style so only the next fish uses it.
	var d := {
		"have": next_fish_have_style,
		"tint": next_fish_tint,
		"sparkle": next_fish_sparkle,
	}
	next_fish_have_style = false
	next_fish_sparkle = false
	return d


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _queue_msg(text: String, tag: String = "GEN") -> void:
	if text == "":
		return

	var n := _now()
	# Drop if still cooling down
	var until := float(_msg_recent_text_until.get(text, 0.0))
	if n < until:
		return

	# Reserve the cooldown immediately so same-frame spam can't enqueue duplicates
	_msg_recent_text_until[text] = n + MSG_SAME_TEXT_COOLDOWN

	# Optional: cap queue length so it can’t balloon
	if _msg_queue.size() >= 10:
		_msg_queue.pop_front()

	_msg_queue.push_back({"text": text, "tag": tag})

	# Kick the pump if idle
	if _msg_tick != null and _msg_tick.is_stopped():
		_msg_tick.start()


func _pump_messages() -> void:
	if _msg_queue.is_empty():
		return

	var n := _now()

	# global min gap
	if n - _msg_last_emit_time < MSG_MIN_GAP:
		_msg_tick.start(max(0.05, MSG_MIN_GAP - (n - _msg_last_emit_time)))
		return

	# burst cap
	if _msg_window_count >= MSG_PER_WINDOW:
		_msg_tick.start(0.25) # try again after a short delay; window resets via timer
		return

	# peek next
	var item = _msg_queue.front()
	var text: String = item["text"]
	var tag: String = item["tag"]

	# per-tag min gap
	var tag_gap := float(MSG_TAG_MIN_GAP.get(tag, 0.0))
	var last_tag_time := float(_msg_last_by_tag.get(tag, -9999.0))
	if n - last_tag_time < tag_gap:
		# not ready for this tag yet—rotate to back and try later
		_msg_queue.pop_front()
		_msg_queue.push_back(item)
		_msg_tick.start(0.15)
		return

	# Emit now (but drop if same as the last emitted within cooldown)
	var norm := _normalize_key(text)
	if norm == _last_emit_norm and (n - _last_emit_time) < MSG_SAME_TEXT_COOLDOWN:
		# Already showed this recently; discard this queued duplicate
		_msg_queue.pop_front()
		if not _msg_queue.is_empty():
			_msg_tick.start(0.15)
		return

	emit_signal("player_message", text)
	print("[EVENTS:%s] %s" % [tag, text])

	_last_emit_norm = norm
	_last_emit_time = n

	# update state
	_msg_last_emit_time = n
	_msg_last_by_tag[tag] = n
	_msg_window_count += 1

	# continue draining if more remain
	if not _msg_queue.is_empty():
		_msg_tick.start(0.15)

func say_once(key: String, text: String, tag: String = "GEN", cooldown: float = 30.0) -> void:
	var n := _now()
	var k := "once:" + key
	if n >= float(_msg_recent_text_until.get(k, 0.0)):
		_msg_recent_text_until[k] = n + cooldown
		_queue_msg(text, tag)
func _normalize_key(text: String) -> String:
	# Normalize for dedupe: trim + lowercase + collapse inner whitespace
	var t := text.strip_edges().to_lower()
	t = t.replace("\r", " ").replace("\n", " ")
	while t.find("  ") != -1:
		t = t.replace("  ", " ")
	return t

func _queue_contains_norm(norm: String) -> bool:
	for it in _msg_queue:
		if _normalize_key(String(it.get("text", ""))) == norm:
			return true
	return false
