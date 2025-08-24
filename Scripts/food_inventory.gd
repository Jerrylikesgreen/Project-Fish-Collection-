class_name Collection
extends ItemList

@onready var collection_button:  = %CollectionButton

@onready var collection_panel: Control = %Collection

@export var icon_px: Vector2i = Vector2i(48, 48)

var _thumb_cache: Dictionary[String, Texture2D] = {}

class Entry:
	var name: String
	var icon: Texture2D
	var count: int = 0

var _entries: Dictionary[String, Entry] = {}

func _ready() -> void:
	# ItemList setup
	fixed_icon_size = icon_px
	select_mode = ItemList.SELECT_SINGLE
	print("[Collection] _ready: fixed_icon_size=%s select_mode=%d" % [str(fixed_icon_size), select_mode])

	# Wire UI toggle
	if collection_button:
		collection_button.pressed.connect(_on_button_pressed)
		print("[Collection] Connected CollectionButton.pressed")
	else:
		push_warning("[Collection] Missing %CollectionButton")

	# Wire Events (defensive in case signals are missing)
	if "collection_discover" in Events:
		Events.collection_discover.connect(_on_discover)
		print("[Collection] Connected Events.collection_discover")
	else:
		push_warning("[Collection] Events lacks collection_discover signal")

	if "collection_add" in Events:
		Events.collection_add.connect(_on_add)
		print("[Collection] Connected Events.collection_add")
	else:
		push_warning("[Collection] Events lacks collection_add signal")

	if "fish_spawned" in Events:
		# NOTE: avoid type-hinting as Fish unless class_name Fish is globally available
		Events.fish_spawned.connect(_on_spawned)
		print("[Collection] Connected Events.fish_spawned")
	else:
		push_warning("[Collection] Events lacks fish_spawned signal")

	# Start empty refresh for sanity
	_refresh_list()
	_debug_dump("after _ready")

func _on_discover(species_id: String, f_name: String, icon: Texture2D) -> void:
	print("[Collection] _on_discover: id=%s name=%s icon=%s" % [species_id, f_name, str(icon)])
	if not _entries.has(species_id):
		var e := Entry.new()
		e.name = f_name
		e.icon = _get_or_make_thumb(species_id, icon)
		e.count = 0
		_entries[species_id] = e
	else:
		# If discover arrives twice, keep first icon unless new one is non-null
		if _entries[species_id].icon == null and icon:
			_entries[species_id].icon = _get_or_make_thumb(species_id, icon)
	_refresh_list()
	_debug_dump("_on_discover")

func _on_add(species_id: String) -> void:
	print("[Collection] _on_add: id=%s" % species_id)
	if _entries.has(species_id):
		_entries[species_id].count += 1
	else:
		push_warning("[Collection] _on_add for unknown id=%s" % species_id)
	_refresh_list()
	_debug_dump("_on_add")

func _on_spawned(fish: Node) -> void:
	if fish == null:
		push_warning("[Collection] _on_spawned got null fish")
		return

	var id := ""
	var f_name := ""
	var evo_icon: Texture2D = null

	if fish.has_method("get_collection_key"):
		id = fish.call("get_collection_key")
	if fish.has_method("get_collection_name"):
		f_name = fish.call("get_collection_name")

	if fish.has_method("get_evolution_icon_texture"):
		evo_icon = fish.call("get_evolution_icon_texture")
	elif fish.has_method("get_icon_texture"):
		evo_icon = fish.call("get_icon_texture")

	print("[Collection] _on_spawned: id=%s name=%s evo_icon=%s fish=%s"
		% [id, f_name, str(evo_icon), str(fish)])

	if id == "":
		push_warning("[Collection] Spawned fish missing id; skipping")
		return

	if not _entries.has(id):
		var e := Entry.new()
		e.name = (f_name if f_name != "" else id)
		e.icon = _get_or_make_thumb(id, evo_icon)
		e.count = 0
		_entries[id] = e

	_entries[id].count += 1
	_refresh_list()
	_debug_dump("_on_spawned")


func _on_button_pressed() -> void:
	if collection_panel:
		collection_panel.visible = not collection_panel.visible
		print("[Collection] toggle panel -> %s" % (str(collection_panel.visible)))
	else:
		# fallback: toggle self
		visible = not visible
		print("[Collection] toggle self -> %s" % str(visible))

func add_fish_to_collection(fish: Node) -> void:
	if fish == null:
		push_warning("[Collection] add_fish_to_collection got null fish")
		return

	var key = (fish.call("get_collection_key") if fish.has_method("get_collection_key") else "")
	if key.is_empty():
		push_warning("[Collection] Fish missing species_id; skipping add.")
		return

	var name = (fish.call("get_collection_name") if fish.has_method("get_collection_name") else key)
	var icon_tex: Texture2D = (fish.call("get_icon_texture") if fish.has_method("get_icon_texture") else null)

	var e: Entry = _entries.get(key)
	if e == null:
		e = Entry.new()
		e.name = name
		e.icon = _get_or_make_thumb(key, icon_tex)
		_entries[key] = e

	print("[Collection] add_fish_to_collection: key=%s name=%s icon=%s count=%d"
		% [key, name, str(icon_tex), e.count])

	_refresh_list()
	_debug_dump("add_fish_to_collection")

func _refresh_list() -> void:
	# Save current state
	var had_focus := has_focus()
	var prev_selected := get_selected_items()

	clear()

	var keys := _entries.keys()
	keys.sort_custom(func(a, b):
		return _entries[a].name.nocasecmp_to(_entries[b].name) < 0
	)

	for key in keys:
		var e: Entry = _entries[key]
		var idx := add_item("%s ×%d" % [e.name, e.count], e.icon)
		set_item_metadata(idx, key)
		# DO NOT select anything here – no select(idx), no ensure_current_is_visible()

	# Restore (optional)
	if had_focus and prev_selected.size() > 0:
		# If you really want to keep selection, uncomment:
		# select(prev_selected[0])
		pass
	else:
		release_focus()


func _get_or_make_thumb(species_id: String, tex: Texture2D) -> Texture2D:
	if _thumb_cache.has(species_id):
		var cached := _thumb_cache[species_id]
		print("[Collection] thumb cache hit id=%s icon=%s" % [species_id, str(cached)])
		return cached

	var result := tex
	if tex == null:
		print("[Collection] _get_or_make_thumb: NULL texture for id=%s; leaving as NULL" % species_id)
	else:
		var img := tex.get_image()
		if img:
			img.resize(icon_px.x, icon_px.y, Image.INTERPOLATE_LANCZOS)
			result = ImageTexture.create_from_image(img)
			print("[Collection] built thumb id=%s from=%s -> thumb=%s" % [species_id, str(tex), str(result)])
		else:
			print("[Collection] get_image() returned NULL for id=%s; using original texture=%s" % [species_id, str(tex)])

	_thumb_cache[species_id] = result
	return result

func _debug_dump(tag: String) -> void:
	print("[Collection] DEBUG DUMP (%s)" % tag)
	print("  entries.size=%d  cache.size=%d  item_count=%d" % [_entries.size(), _thumb_cache.size(), item_count])
	for id in _entries.keys():
		var e: Entry = _entries[id]
		print("   • id=%s name=%s count=%d icon=%s (cached=%s)" %
			[id, e.name, e.count, str(e.icon), str(_thumb_cache.get(id))])
