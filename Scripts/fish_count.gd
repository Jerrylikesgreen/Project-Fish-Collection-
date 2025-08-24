extends Label

var tank_count: int = 0

func _ready() -> void:
	# Connect once (defensive)
	if "fish_spawned" in Events and not Events.fish_spawned.is_connected(_on_fish_spawned):
		Events.fish_spawned.connect(_on_fish_spawned)
	if "fish_sold_signal" in Events and not Events.fish_sold_signal.is_connected(_on_fish_sold):
		Events.fish_sold_signal.connect(_on_fish_sold)

	_refresh_from_world("ready")

func _on_fish_spawned(_fish = null) -> void:
	_refresh_from_world("spawned")

func _on_fish_sold() -> void:
	_refresh_from_world("sold")

func _refresh_from_world(reason: String) -> void:
	# Truth source = live nodes in group "fish"
	var live := get_tree().get_nodes_in_group("fish").size()
	tank_count = clampi(live, 0, Globals.max_fish_count)

	text = "%d / %d" % [tank_count, Globals.max_fish_count]
	print("[TankLabel] %s -> live=%d / %d" % [reason, tank_count, Globals.max_fish_count])
