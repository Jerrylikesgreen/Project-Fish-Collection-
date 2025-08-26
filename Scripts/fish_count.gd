extends Label

var tank_count: int = 0
@onready var upgrade_button: UpgradeButton = %UpgradeButton

func _ready() -> void:
	Events.update_ui.connect(_refresh_from_world)
	if "fish_spawned" in Events and not Events.fish_spawned.is_connected(_on_fish_spawned):
		Events.fish_spawned.connect(_on_fish_spawned)
	if "fish_sold_signal" in Events and not Events.fish_sold_signal.is_connected(_on_fish_sold):
		Events.fish_sold_signal.connect(_on_fish_sold)
	upgrade_button.pressed.connect(_on_signal)

	_refresh_from_world("ready")

func _on_fish_spawned(_fish = null) -> void:
	_refresh_from_world("spawned")

func _on_fish_sold() -> void:
	_refresh_from_world("sold")

func _on_signal()->void:

	text = "%d / %d" % [tank_count, Globals.max_fish_count]
	print("[TankLabel] %s -> live=%d / %d" % [tank_count, Globals.max_fish_count])


func _refresh_from_world(reason: String) -> void:
	print("Reff")
	var live := get_tree().get_nodes_in_group("fish").size()
	tank_count = clampi(live, 0, Globals.max_fish_count)

	text = "%d / %d" % [tank_count, Globals.max_fish_count]
	print("[TankLabel] %s -> live=%d / %d" % [reason, tank_count, Globals.max_fish_count])
