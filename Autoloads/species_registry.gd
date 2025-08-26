
extends Node

const SIL_DIR := "res://Resources/CollectionSilhouettes"

var ALL_SPECIES: Dictionary = {}  # id -> {name, silhouette: Texture2D}

func _ready() -> void:
	var dir := DirAccess.open(SIL_DIR)
	if dir == null: 
		push_error("Missing silhouettes dir: " + SIL_DIR); return
	dir.list_dir_begin()
	while true:
		var f := dir.get_next()
		if f == "": break
		if dir.current_is_dir(): continue
		if f.ends_with("_sil.png"):
			var id := f.replace("_sil.png","")
			var sil: Texture2D = load(SIL_DIR + "/" + f)
			ALL_SPECIES[id] = {
				"name": id.capitalize(),  # or load a nicer name from a map
				"silhouette": sil
			}
	dir.list_dir_end()
