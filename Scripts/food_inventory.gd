class_name Collection
extends ItemList

@export var icon_px: Vector2i = Vector2i(48, 48)
@export var placeholder_icon: Texture2D
@export var undiscovered_label: String = "????"

# species_id -> Texture2D (thumbnails)
var _thumb_cache: Dictionary[String, Texture2D] = {}

# Simple entry container
class Entry:
	var name: String
	var icon: Texture2D
	var count: int = 0
	var revealed: bool = false

# species_id -> Entry
var _entries: Dictionary[String, Entry] = {}

func _ready() -> void:
	fixed_icon_size = icon_px
	select_mode = ItemList.SELECT_SINGLE
	print("[Collection] _ready: fixed_icon_size=%s select_mode=%d" % [str(fixed_icon_size), select_mode])

	# Show/hide via Events
	if "open_collections_screen" in Events:
		Events.open_collections_screen.connect(_on_button_set_visible)

	# Reveal handler (evolution moment)
	if "collection_discover" in Events:
		Events.collection_discover.connect(_on_discover)
	else:
		push_warning("[Collection] Events lacks collection_discover signal")

	# Spawn handler: create/update placeholder entries until revealed
	if "fish_spawned" in Events:
		Events.fish_spawned.connect(_on_spawned)

	_refresh_list()
	_debug_dump("after _ready")

# --------- Event handlers ---------

# Spawned fish: ensure placeholder entry exists and bump count.
# No species/name/icon reveal here.
func _on_spawned(fish: Node) -> void:
	if fish == null:
		push_warning("[Collection] _on_spawned got null fish")
		return

	var id := ""
	if fish.has_method("get_collection_key"):
		id = String(fish.call("get_collection_key"))

	if id == "":
		push_warning("[Collection] Spawned fish missing id; skipping")
		return

	var e: Entry = _entries.get(id)
	if e == null:
		e = Entry.new()
		e.revealed = false
		e.name = undiscovered_label
		e.icon = _get_or_make_thumb(id, placeholder_icon)  # placeholder art
		e.count = 0
		_entries[id] = e

	e.count += 1
	print("[Collection] spawn -> id=%s placeholder count=%d" % [id, e.count])

	_refresh_list()

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

	# IMPORTANT: drop any placeholder thumb so we rebuild with the real icon
	if _thumb_cache.has(species_id):
		_thumb_cache.erase(species_id)

	e.icon = _get_or_make_thumb(species_id, icon)
	e.count = _recount_species(species_id)

	_refresh_list()
	_debug_dump("_on_discover")


# Explicit visibility toggle
func _on_button_set_visible(enabled: bool) -> void:
	visible = enabled
	print("[Collection] visible -> %s" % str(visible))

# --------- Internal UI/util ---------
func _refresh_list() -> void:
	clear()

	# Sort by display name (revealed entries use real name, hidden use undiscovered_label)
	var keys := _entries.keys()
	keys.sort_custom(func(a, b):
		var na := _entries[a].name
		var nb := _entries[b].name
		return na.nocasecmp_to(nb) < 0
	)

	for key in keys:
		var e: Entry = _entries[key]
		var label := e.name + " ×" + str(e.count)
		var idx := add_item(label, e.icon)
		set_item_metadata(idx, key)

func _get_or_make_thumb(species_id: String, tex: Texture2D) -> Texture2D:
	if _thumb_cache.has(species_id):
		var cached := _thumb_cache[species_id]
		print("[Collection] thumb cache hit id=%s icon=%s" % [species_id, str(cached)])
		return cached

	var result: Texture2D = tex
	if tex == null:
		print("[Collection] _get_or_make_thumb: NULL texture for id=%s; leaving NULL" % species_id)
	else:
		var img := tex.get_image()
		if img != null:
			img.resize(icon_px.x, icon_px.y, Image.INTERPOLATE_LANCZOS)
			result = ImageTexture.create_from_image(img)
			print("[Collection] built thumb id=%s from=%s -> thumb=%s" % [species_id, str(tex), str(result)])
		else:
			print("[Collection] get_image() was NULL for id=%s; using original texture=%s" % [species_id, str(tex)])

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

func _debug_dump(tag: String) -> void:
	print("[Collection] DEBUG DUMP (%s)" % tag)
	print("  entries.size=%d  cache.size=%d  item_count=%d" % [_entries.size(), _thumb_cache.size(), item_count])
	for id in _entries.keys():
		var e: Entry = _entries[id]
		print("   • id=%s name=%s count=%d revealed=%s icon=%s (cached=%s)" %
			[id, e.name, e.count, str(e.revealed), str(e.icon), str(_thumb_cache.get(id))])
