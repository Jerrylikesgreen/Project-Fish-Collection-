# "res://Scripts/screenshot_button.gd"
extends Button

@export var screenshot_dir: String = "user://screenshots"  # must match your ScreenshotManager

func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_disabled_state()

func _on_pressed() -> void:
	if OS.has_feature("web"):
		# Browsers can't open the local file system directly
		_show_toast("On Web builds, screenshots are stored in the browser sandbox. Use an in-game gallery or export to download.")
		return

	var abs_dir := ProjectSettings.globalize_path(screenshot_dir)
	# Ensure the folder exists
	DirAccess.make_dir_recursive_absolute(abs_dir)
	# Open in OS file explorer
	OS.shell_open(abs_dir)

func _update_disabled_state() -> void:
	# Disable if running on web (no shell_open) to avoid confusion
	if OS.has_feature("web"):
		disabled = true
		tooltip_text = "Not available on Web builds."
	else:
		disabled = false
		tooltip_text = "Open the screenshots folder."

func _show_toast(msg: String) -> void:
	# Lightweight fallback: print + optional popup if you add one
	push_warning(msg)
