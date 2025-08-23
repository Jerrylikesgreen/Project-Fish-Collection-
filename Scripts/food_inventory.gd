class_name Collection
extends ItemList

@onready var collection_button: Button = %CollectionButton
@onready var collection_panel: Control = %Collection   # the outer panel you toggle (or remove and toggle self)

# Nice to keep icons consistent
@export var icon_px: Vector2i = Vector2i(48, 48)

# Cache thumbnails so we don’t rebuild every refresh
var _thumb_cache: Dictionary[String, Texture2D] = {}

# Simple entry holder
class Entry:
	var name: String
	var icon: Texture2D
	var count: int = 0

# species_id -> Entry
var _entries: Dictionary[String, Entry] = {}

func _ready() -> void:
	fixed_icon_size = icon_px
	select_mode = ItemList.SELECT_SINGLE
	collection_button.pressed.connect(_on_button_pressed)
	Events.collection_discover.connect(_on_discover)
	Events.collection_add.connect(_on_add)  # if you gate counts on “caught”
	Events.fish_spawned.connect(_on_spawned) # if you count spawns, not catches

func _on_discover(species_id: String, name: String, icon: Texture2D) -> void:
	if not _entries.has(species_id):
		_entries[species_id] = Entry.new()
		_entries[species_id].name = name
		_entries[species_id].icon = icon
		_entries[species_id].count = 0
		_refresh_list()

func _on_add(species_id: String) -> void:
	if _entries.has(species_id):
		_entries[species_id].count += 1
		_refresh_list()

func _on_spawned(fish: Fish) -> void:
	var id := fish.species_id
	var name := fish.get_collection_name()
	if not _entries.has(id):
		_entries[id] = Entry.new()
		_entries[id].name = name
		_entries[id].icon = fish.get_icon_texture()
		_entries[id].count = 0
	_entries[id].count += 1
	_refresh_list()

func _on_button_pressed() -> void:
	if collection_panel.visible == true:
		visible = false
	else:
		visible = true

func add_fish_to_collection(fish: Fish) -> void:
	
	if fish == null:
		return
	
	var key := fish.get_collection_key()
	if key.is_empty():
		push_warning("Fish missing species_id; skipping add.")
		return

	var e = _entries.get(key)
	if e == null:
		e = Entry.new()
		e.name = fish.get_collection_name()
		e.icon = _get_or_make_thumb(key, fish.get_icon_texture())
		e.count = 1
		_entries[key] = e
	else:
		e.count += 1
	print(fish)

	_refresh_list()

func _refresh_list() -> void:
	clear()

	var keys := _entries.keys()
	keys.sort_custom(func(a, b):
		return _entries[a].name.nocasecmp_to(_entries[b].name) < 0
	)

	for key in keys:
		var e: Entry = _entries[key]
		var idx := add_item("%s ×%d" % [e.name, e.count], e.icon)
		set_item_metadata(idx, key)


func _get_or_make_thumb(species_id: String, tex: Texture2D) -> Texture2D:
	if _thumb_cache.has(species_id):
		return _thumb_cache[species_id]


	var result := tex
	if tex != null:
		var img := tex.get_image()
		if img:
			img.resize(icon_px.x, icon_px.y, Image.INTERPOLATE_LANCZOS)
			result = ImageTexture.create_from_image(img)
	pass

	_thumb_cache[species_id] = result
	return result
