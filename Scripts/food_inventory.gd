class_name Collection
extends ItemList

const SAVE_PATH := "user://collection.save"
@export var icon_px: Vector2i = Vector2i(48, 48)
@export var placeholder_icon: Texture2D
@export var undiscovered_label: String = "????"
@onready var collections: VBoxContainer = %Collections

# species_id -> Texture2D (thumbnails)
var _thumb_cache: Dictionary[String, Texture2D] = {}
const RARITIES := ["Base","Gold","Green","Pink"]
const RARITY_COLORS := { # optional, for icon tint
	0: Color(1,1,1,1),       # Base
	1: Color(1.00,0.90,0.30,1), # Gold
	2: Color(0.50,1.00,0.60,1), # Green
	3: Color(1.00,0.55,0.85,1), # Pink
}

func _rarity_label(idx: int) -> String:
	return RARITIES[idx] if idx >= 0 and idx < RARITIES.size() else "Base"


# Simple entry container
class Entry:
	var name: String
	var icon: Texture2D
	var revealed: bool = false
	var rarity_idx: int = 0
	var rarity_name: String = "Base"
# species_id -> Entry
var _entries: Dictionary[String, Entry] = {}

func _ready() -> void:
	fixed_icon_size = icon_px
	select_mode = ItemList.SELECT_SINGLE

	_seed_all_species_from_registry()
	_load_discoveries()

	if "open_collections_screen" in Events:
		Events.open_collections_screen.connect(_on_button_set_visible)
	if "collection_discover" in Events:
		Events.collection_discover.connect(_on_discover)
	if "fish_spawned" in Events:
		Events.fish_spawned.connect(_on_spawned)

	print("[Collection] seeded species=", _entries.size())
	_refresh_list()
	_debug_dump("after _ready")
	print("[Collection] ALL_SPECIES count=", SpeciesRegistry.ALL_SPECIES.size())
	for id in SpeciesRegistry.ALL_SPECIES.keys():
		var sil_ok = SpeciesRegistry.ALL_SPECIES[id].has("silhouette") and SpeciesRegistry.ALL_SPECIES[id]["silhouette"] != null
		print("  -", id, " silhouette=", sil_ok)
	
	print("[Collection] ItemList item_count=", item_count, " fixed_icon_size=", fixed_icon_size)




func _seed_all_species_from_registry() -> void:
	for id in SpeciesRegistry.ALL_SPECIES.keys():
		if not _entries.has(id):
			var data = SpeciesRegistry.ALL_SPECIES[id]
			var e := Entry.new()
			e.revealed = false
			e.name = undiscovered_label
			e.icon = _get_or_make_thumb(id, data["silhouette"])  # species-specific silhouette
			e.rarity_idx = 0
			e.rarity_name = "Base"
			_entries[id] = e

# --------- Event handlers ---------

# Spawned fish: ensure placeholder entry exists and bump count.
# No species/name/icon reveal here.
func _on_spawned(fish: Node) -> void:
	if fish == null: return

	var id := ""
	if fish.has_method("get_collection_key"):
		id = String(fish.call("get_collection_key"))
	if id == "": return

	var r_idx := 0
	var v = fish.get("rarity")
	if v is int: r_idx = v

	var e: Entry = _entries.get(id)
	if e == null:
		e = Entry.new()
		_entries[id] = e

	# If not revealed yet, flip name & icon
	if not e.revealed:
		e.revealed = true
		e.name = (fish.get_collection_name() if fish.has_method("get_collection_name") else id)
		# Try to pull a real icon from the fish
		var icon_tex: Texture2D = null
		if fish.has_method("get_icon_texture"):
			icon_tex = fish.call("get_icon_texture")
		if icon_tex == null:
			# fallback to whatever the anim has, or keep silhouette
			var data = SpeciesRegistry.ALL_SPECIES.get(id, null)
			icon_tex = (data and data.get("silhouette"))  # last resort
		if icon_tex != null:
			if _thumb_cache.has(id): _thumb_cache.erase(id)
			e.icon = _get_or_make_thumb(id, icon_tex)

	# track best rarity seen
	if r_idx > e.rarity_idx:
		e.rarity_idx = r_idx
		e.rarity_name = _rarity_label(r_idx)

	_refresh_list()
	_save_discoveries()



# Evolution reveal: swap placeholder to real name/icon, and recount
func _on_discover(species_id: String, f_name: String, icon: Texture2D) -> void:
	print("[Collection] DISCOVER: id=%s name=%s icon=%s" % [species_id, f_name, str(icon)])
	if species_id == "":
		push_warning("[Collection] discover missing species_id")
		return

	var e: Entry = _entries.get(species_id)
	if e == null:
		e = Entry.new()
		_entries[species_id] = e

	e.revealed = true
	e.name = (f_name if f_name != "" else species_id)

	if _thumb_cache.has(species_id):
		_thumb_cache.erase(species_id)

	# If discover passes null icon in Web, fall back to silhouette or placeholder
	var sil: Texture2D = SpeciesRegistry.ALL_SPECIES.get(species_id, {}).get("silhouette", null)
	e.icon = _get_or_make_thumb(species_id, icon if icon != null else sil)

	_refresh_list()
	_debug_dump("_on_discover")




# Explicit visibility toggle
func _on_button_set_visible(enabled: bool) -> void:
	collections.visible = enabled
	print("[Collection] visible -> %s" % str(visible))

# --------- Internal UI/util ---------
func _refresh_list() -> void:
	clear()
	var keys := _entries.keys()
	keys.sort_custom(func(a, b):
		var ea := _entries[a]
		var eb := _entries[b]
		if ea.revealed != eb.revealed:
			return ea.revealed and not eb.revealed
		return ea.name.nocasecmp_to(eb.name) < 0
	)

	for key in keys:
		var e: Entry = _entries[key]
		var label := e.name
		if e.revealed:
			label += " [" + e.rarity_name + "]"
		# Even if icon is null, still add the item so you see labels
		var idx := add_item(label, e.icon)
		set_item_metadata(idx, key)
		set_item_icon_modulate(idx, Color(1,1,1,1) if e.revealed else Color(0.7,0.7,0.7,1))
		set_item_tooltip(idx, "Rarity: %s" % e.rarity_name if e.revealed else "Unseen")





@export var flip_icons_horizontally := false  # avoid get_image() on Web

func _get_or_make_thumb(species_id: String, tex: Texture2D) -> Texture2D:
	if _thumb_cache.has(species_id):
		return _thumb_cache[species_id]

	var result: Texture2D = tex
	if result == null:
		result = placeholder_icon

	if flip_icons_horizontally and result != null and result is ImageTexture:
		var img := result.get_image()
		if img:
			img.flip_x()
			result = ImageTexture.create_from_image(img)

	_thumb_cache[species_id] = result
	return result



func _recount_species(species_id: String) -> int:
	var n := 0
	var nodes := get_tree().get_nodes_in_group("fish")
	for node in nodes:
		if node != null and node.has_method("get_collection_key"):
			var kid := String(node.call("get_collection_key"))
			if kid == species_id:
				n += 1
	print("[Collection] recount id=%s -> %d" % [species_id, n])
	return n



func _save_discoveries() -> void:
	var cfg := ConfigFile.new()
	for id in _entries.keys():
		var e: Entry = _entries[id]
		cfg.set_value("collection", id + ":revealed", e.revealed)
		cfg.set_value("collection", id + ":rarity_idx", e.rarity_idx)
	cfg.save(SAVE_PATH)

func _load_discoveries() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK: return
	for id in SpeciesRegistry.ALL_SPECIES.keys():
		var e: Entry = _entries.get(id)
		if e == null:
			e = Entry.new()
			_entries[id] = e
		e.revealed = bool(cfg.get_value("collection", id + ":revealed", false))
		e.rarity_idx = int(cfg.get_value("collection", id + ":rarity_idx", 0))
		e.rarity_name = _rarity_label(e.rarity_idx)
		# If revealed but still showing silhouette, try to create a real icon from cache or leave as-is (it'll update on next spawn/discover)


func _debug_dump(tag: String) -> void:
	print("[Collection] DEBUG DUMP (%s)" % tag)
	print("  entries.size=%d  cache.size=%d  item_count=%d" % [_entries.size(), _thumb_cache.size(), item_count])
	for id in _entries.keys():
		var e: Entry = _entries[id]
		print("   • id=%s name=%s revealed=%s icon=%s (cached=%s)" %
			[id, e.name,  str(e.revealed), str(e.icon), str(_thumb_cache.get(id))])
