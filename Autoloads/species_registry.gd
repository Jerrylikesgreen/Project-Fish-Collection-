extends Node

const SIL_DIR := "res://Resources/CollectionSilhouettes"

# ✅ Put at least the species you showed in logs:
const SIL_FILES := [
	"starter_sil.png",
	"blob_sil.png",
	"hello_catfish_sil.png",
	"jiggly_sil.png",
	"pika_tadpol_sil.png",
	"betta_sil.png",
	"blue_fish_sil.png",
	"chorse_sil.png",
	"eelton_john_sil.png",
	"marge_shrimpson_sil.png",
	"princess_peach_sil.png",
	
	
	
]

var ALL_SPECIES: Dictionary = {}  # id -> { name, silhouette: Texture2D }

func _ready() -> void:
	if OS.has_feature("editor"):
		_load_by_scanning()
	else:
		_load_from_baked_list()
	print("[Registry] species=", ALL_SPECIES.size())

func _load_from_baked_list() -> void:
	for f in SIL_FILES:
		var id = f.replace("_sil.png","")
		var path = SIL_DIR + "/" + f
		# This proves the file is in the PCK:
		if ResourceLoader.exists(path):
			var sil: Texture2D = load(path)
			ALL_SPECIES[id] = {"name": id.capitalize(), "silhouette": sil}
		else:
			push_warning("[SpeciesRegistry] Missing in export: " + path)

func _load_by_scanning() -> void:
	var dir := DirAccess.open(SIL_DIR)
	if dir == null:
		push_error("Missing silhouettes dir: " + SIL_DIR)
		return
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "": break
		if dir.current_is_dir(): continue
		if f.ends_with("_sil.png"):
			var id := f.replace("_sil.png","")
			var sil: Texture2D = load(SIL_DIR + "/" + f)
			ALL_SPECIES[id] = {"name": id.capitalize(), "silhouette": sil}
	dir.list_dir_end()
