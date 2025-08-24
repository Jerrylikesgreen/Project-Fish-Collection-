#  "res://Scripts/reveal_last_screenshot_button.gd"
extends Button

@export var screenshot_dir: String = "user://screenshots"

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if OS.has_feature("web"):
		push_warning("Not available on Web builds.")
		return

	var abs_dir := ProjectSettings.globalize_path(screenshot_dir)
	var last := _get_latest_png(abs_dir)
	if last.is_empty():
		push_warning("No screenshots found yet.")
		return
	OS.shell_open(last)  # opens the file (or the default app)

func _get_latest_png(abs_dir: String) -> String:
	var d := DirAccess.open(abs_dir)
	if d == null:
		return ""
	var newest_path := ""
	var newest_time := -1
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if d.current_is_dir():
			continue
		if not name.to_lower().ends_with(".png"):
			continue
		var p := abs_dir.path_join(name)
		var mtime := FileAccess.get_modified_time(p)
		if mtime > newest_time:
			newest_time = mtime
			newest_path = p
	d.list_dir_end()
	return newest_path
