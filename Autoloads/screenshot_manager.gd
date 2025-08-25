extends Node

const SCREENSHOT_DIR := "user://screenshots"
const DEBUG := true

@export var show_flash := true
@export var show_toast := true
@export var toast_seconds := 1.6
@export var toast_max_width := 520.0
@export var shutter_sfx: AudioStream
@export var download_on_web := true   # ⟵ NEW: offer a browser download after saving

var _flash_layer: CanvasLayer
var _flash_rect: ColorRect
var _toast_layer: CanvasLayer
var _toast_panel: PanelContainer
var _toast_label: Label
var _sfx: AudioStreamPlayer

func _ready() -> void:
	# Make sure the directory exists (works on desktop, mobile, web)
	if not DirAccess.dir_exists_absolute(SCREENSHOT_DIR):
		DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)

	if DEBUG:
		var abs := ProjectSettings.globalize_path(SCREENSHOT_DIR)
		print("[ScreenshotManager] Ready →", SCREENSHOT_DIR, " (", abs, ")")
		print("[ScreenshotManager] InputMap: Screenshot=", InputMap.has_action("Screenshot"),
			" ScreenshotClean=", InputMap.has_action("ScreenshotClean"))
	_ensure_indicator_nodes()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Screenshot"):
		if DEBUG: print("[ScreenshotManager] Hotkey Screenshot")
		take_screenshot(true)
	elif event.is_action_pressed("ScreenshotClean"):
		if DEBUG: print("[ScreenshotManager] Hotkey ScreenshotClean")
		take_screenshot(false)

func take_screenshot(include_ui: bool = true) -> void:
	if DEBUG: print("[ScreenshotManager] Taking screenshot… include_ui=", include_ui)

	# Ensure the frame is fully drawn on all platforms
	await get_tree().process_frame

	var img: Image
	var hidden: Array = []
	if include_ui:
		img = get_viewport().get_texture().get_image()
	else:
		hidden = _set_ui_visible(false)
		await get_tree().process_frame
		img = get_viewport().get_texture().get_image()
		_set_ui_visible(true, hidden)

	if img == null:
		push_warning("[ScreenshotManager] Image capture returned null")
		return

	# Web/GL usually needs vertical flip
	img.flip_y()

	var path := _unique_path()
	var err := img.save_png(path)
	if err == OK:
		# Also trigger a browser download on Web, if you want
		if OS.has_feature("web") and download_on_web:
			var bytes := img.save_png_to_buffer()
			_download_in_browser_as(path.get_file(), bytes)
	
		print("📸 Saved screenshot:", path)
		_indicator_flash()
		_indicator_toast(_saved_msg_for_current_platform(path))
		_indicator_sfx()
	else:
		push_warning("[ScreenshotManager] Failed to save (code=%s) → %s" % [str(err), path])


func _unique_path() -> String:
	var ts := Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	return SCREENSHOT_DIR + "/screenshot_" + ts + ".png"

func _saved_msg_for_current_platform(p: String) -> String:
	if OS.has_feature("web"):
		var suffix := " & downloaded." if download_on_web else "."
		return "Screenshot saved to browser storage" + suffix
	return "Saved: " + _humanize_user_path(p)



# ─────────────────────────────────────────────────────────────
# (Your existing UI hiding, indicators, etc. unchanged below)

func _set_ui_visible(visible: bool, restore_list: Array = []) -> Array:
	var affected: Array = []
	if restore_list.size() > 0:
		for n in restore_list:
			if n and is_instance_valid(n):
				n.visible = visible
				affected.append(n)
		return affected

	var seen := {}
	for cl in get_tree().get_nodes_in_group("CanvasLayerGroup"):
		if cl and is_instance_valid(cl) and cl.visible != visible:
			cl.visible = visible
			if not seen.has(cl): seen[cl] = true
			affected.append(cl)

	for n in get_tree().get_nodes_in_group("ui"):
		if n and is_instance_valid(n) and n is CanvasItem and n.visible != visible:
			n.visible = visible
			if not seen.has(n): seen[n] = true
			affected.append(n)
	return affected

# … keep your _ensure_indicator_nodes(), _indicator_flash(), _indicator_toast(), _indicator_sfx() …

func _humanize_user_path(p: String) -> String:
	return ProjectSettings.globalize_path(p)





func _ensure_indicator_nodes() -> void:
	# FLASH (full-screen white ColorRect on a high CanvasLayer)
	if _flash_layer == null:
		_flash_layer = CanvasLayer.new()
		_flash_layer.layer = 1000  # above typical UI
		add_child(_flash_layer)     # not added to any groups → won't be hidden
	if _flash_rect == null:
		_flash_rect = ColorRect.new()
		_flash_rect.color = Color(1, 1, 1, 0) # invisible white
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.visible = false
		_flash_layer.add_child(_flash_rect)

	# TOAST (small panel + label near top-center)
	if _toast_layer == null:
		_toast_layer = CanvasLayer.new()
		_toast_layer.layer = 1001
		add_child(_toast_layer)

	if _toast_panel == null:
		_toast_panel = PanelContainer.new()
		_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toast_panel.visible = false
		_toast_panel.modulate.a = 0.0
		_toast_panel.add_theme_constant_override("margin_left", 12)
		_toast_panel.add_theme_constant_override("margin_right", 12)
		_toast_panel.add_theme_constant_override("margin_top", 8)
		_toast_panel.add_theme_constant_override("margin_bottom", 8)
		_toast_panel.add_theme_constant_override("separation", 6)
		_toast_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_toast_panel.offset_top = 16
		_toast_panel.offset_left = 0
		_toast_panel.offset_right = 0
		_toast_layer.add_child(_toast_panel)

		if _toast_label == null:
			_toast_label = Label.new()
			_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_toast_label.clip_text = true
			_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_toast_panel.add_child(_toast_label)

	# SFX
	if _sfx == null:
		_sfx = AudioStreamPlayer.new()
		_sfx.bus = "Master"
		add_child(_sfx)

func _indicator_flash() -> void:
	if not show_flash:
		return
	_flash_rect.visible = true
	_flash_rect.color = Color(1, 1, 1, 0)
	var t := create_tween()
	t.tween_property(_flash_rect, "color:a", 0.7, 0.08).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_flash_rect, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.finished.connect(func():
		_flash_rect.visible = false
	)

func _indicator_toast(msg: String) -> void:
	if not show_toast:
		return
	_toast_label.text = msg
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0

	# limit width so it looks nice
	_toast_panel.custom_minimum_size.x = toast_max_width

	var t := create_tween()
	t.tween_property(_toast_panel, "modulate:a", 1.0, 0.12).from(0.0)
	t.tween_interval(max(0.2, toast_seconds - 0.34))
	t.tween_property(_toast_panel, "modulate:a", 0.0, 0.22)
	t.finished.connect(func():
		_toast_panel.visible = false
	)

func _indicator_sfx() -> void:
	if shutter_sfx == null:
		return
	_sfx.stream = shutter_sfx
	_sfx.play()
	

func _download_in_browser_as(filename: String, bytes: PackedByteArray) -> void:
	if not OS.has_feature("web"):
		return
	var b64 := Marshalls.raw_to_base64(bytes)
	var js := """
	(function(fileName, base64){
		try{
			const a = document.createElement('a');
			a.href = 'data:image/png;base64,' + base64;
			a.download = fileName;
			document.body.appendChild(a);
			a.click();
			a.remove();
			return true;
		}catch(e){ console.error(e); return false; }
	})
	"""
	var args_json := JSON.stringify([filename, b64])
	JavaScriptBridge.eval(js + "(" + args_json + ");")
