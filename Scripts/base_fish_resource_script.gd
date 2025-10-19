# FishResource.gd
class_name FishResource
extends Resource

const BASE_SIL = preload("uid://b7o0pjkyjuf7x")
const BASE_FISH_FRAME = preload("uid://d04n5or4127m4")
const BUBBLE = preload("uid://cymgrmkugrum7")

@export var sprite: SpriteFrames
@export var fish_sell_value: int = 3
@export_custom(PROPERTY_HINT_NONE, "Species Id is Int") var species_id: int
@export var display_name: String

@export_category("Fish Effects")
@export_flags(
	"Fast Swimmer",
	"Slow Swimmer",
	"Popper",
	"Feedder",
	"Large Belly",
	"Small Belly",
	"Bubble Enthusiast",
	"More Valuable",
	"Enpowered"
) var fish_effect: int = 0

# Bit flags
const FISH_FAST_SWIMMER      = 1 << 0
const FISH_SLOW_SWIMMER      = 1 << 1
const FISH_POPPER            = 1 << 2
const FISH_FEEDDER           = 1 << 3
const FISH_LARGE_BELLY       = 1 << 4
const FISH_SMALL_BELLY       = 1 << 5
const FISH_BUBBLE_ENTHUSIAST = 1 << 6
const FISH_MORE_VALUABLE     = 1 << 7
const FISH_ENPOWERED         = 1 << 8

const _EFFECTS_META := {
	FISH_FAST_SWIMMER: {
		"name": "Fast Swimmer",
		"description": "Moves faster.",
		"speed_mult": 1.5
	},
	FISH_SLOW_SWIMMER: {
		"name": "Slow Swimmer",
		"description": "Moves slower.",
		"speed_mult": 0.7
	},
	FISH_POPPER: {
		"name": "Popper",
		"description": "Pops bubbles (spawns bubble on action).",
		"popper_action": true
	},
	FISH_FEEDDER: {
		"name": "Feedder",
		"description": "Produces food.",
		"food_spawn_tick": 1.5
	},
	FISH_LARGE_BELLY: {
		"name": "Large Belly",
		"description": "Needs more food to Transform.",
		"evolution_thresh_multi": 2.0
	},
	FISH_SMALL_BELLY: {
		"name": "Small Belly",
		"description": "Needs less food top Transform.",
		"evolution_thresh_multi": -1.0
	},
	FISH_BUBBLE_ENTHUSIAST: {
		"name": "Bubble Enthusiast",
		"description": "Spawns bubbles more frequently.",
		"bubble_rate_mult": 1.8
	},
	FISH_MORE_VALUABLE: {
		"name": "More Valuable",
		"description": "Sells for more.",
		"sell_mult": 2.0
	},
	FISH_ENPOWERED: {
		"name": "Enpowered",
		"description": "Placeholder",
		"speed_mult": 1.2,
	}
}

# ---------- Flag helpers ----------
# Check for ANY / ALL flags (same you had, but included for completeness)
func has_effect(effect: int, require_all: bool = false) -> bool:
	if require_all:
		return (fish_effect & effect) == effect
	else:
		return (fish_effect & effect) != 0

# Return list of active effect names (human readable)
func get_effects() -> Array:
	var out := []
	for flag in _EFFECTS_META.keys():
		if fish_effect & flag:
			out.append(_EFFECTS_META[flag].name)
	return out

# Return dictionary keyed by effect name -> bool active (useful for UI toggles)
func get_effects_dict() -> Dictionary:
	var out := {}
	for flag in _EFFECTS_META.keys():
		var name = _EFFECTS_META[flag].name
		out[name] = (fish_effect & flag) != 0
	return out

# ---------- Combined modifiers ----------
# Compute a single Dictionary of combined modifiers based on all active effects.
# Returns defaults when no effect present.
# Keys returned (example): speed_mult, sell_mult, food_spawn_tick, evolution_thresh_multi, bubble_rate_mult, popper_action (bool)
func compute_stat_modifiers() -> Dictionary:
	# Start with neutral defaults
	var mods := {
		"speed_mult": 1.0,
		"sell_mult": 1.0,
		"food_spawn_tick": 1.0,
		"evolution_thresh_multi": 0,
		"bubble_rate_mult": 1.0,
		"popper_action": false
	}

	# Merge each active effect into mods.
	# Multiplicative modifiers will be multiplied; additive ones added.
	for flag in _EFFECTS_META.keys():
		if fish_effect & flag:
			var meta = _EFFECTS_META[flag]
			if meta.has("speed_mult"):
				mods["speed_mult"] *= meta["speed_mult"]
			if meta.has("sell_mult"):
				mods["sell_mult"] *= meta["sell_mult"]
			if meta.has("food_spawn_tick"):
				mods["food_spawn_tick"] *= meta["food_spawn_tick"]
			if meta.has("evolution_thresh_multi"):
				mods["evolution_thresh_multi"] += int(meta["evolution_thresh_multi"])
			if meta.has("bubble_rate_mult"):
				mods["bubble_rate_mult"] *= meta["bubble_rate_mult"]
			if meta.has("popper_action"):
				# if any effect triggers popper_action, set true
				mods["popper_action"] = mods["popper_action"] or bool(meta["popper_action"])

	return mods

func apply_modifiers_to_base(base_stats: Dictionary) -> Dictionary:
	var mods = compute_stat_modifiers()
	var res := base_stats.duplicate(true)

	# Apply multiplicative / additive transforms safely
	if res.has("speed"):
		res["speed"] = res["speed"] * mods["speed_mult"]
	if res.has("sell_value"):
		# round or floor as desired
		res["sell_value"] = int(round(float(res["sell_value"]) * mods["sell_mult"]))
	if res.has("appetite"):
		res["appetite"] = res["appetite"] * mods["food_spawn_tick"]
	if res.has("capacity"):
		res["capacity"] = int(res["capacity"]) + mods["evolution_thresh_multi"]
	if res.has("bubble_rate"):
		res["bubble_rate"] = res["bubble_rate"] * mods["bubble_rate_mult"]

	# You may want to clamp values (e.g. capacity >= 0)
	if res.has("capacity"):
		res["capacity"] = max(0, int(res["capacity"]))

	# Attach popper_action as metadata if needed
	res["popper_action"] = mods["popper_action"]

	return res
