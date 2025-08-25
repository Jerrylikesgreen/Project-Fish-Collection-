# res://UI/CameraIconButton.gd
extends Button
## A crisp, scalable camera line icon drawn directly on a Button (Godot 4.x).
## Works with hover/pressed/focus states and respects the node's size.

@export var stroke: float = 2.0                   # outline thickness in px (will scale slightly with size)
@export var body_radius_ratio: float = 0.16       # rounded-corner radius as ratio of min(size)
@export var lens_ratio: float = 0.22              # lens radius as ratio of min(size)
@export var hump_width_ratio: float = 0.34        # width of "viewfinder hump" on top of body
@export var hump_height_ratio: float = 0.18       # height of "viewfinder hump"

@export var color_normal: Color  = Color(0.95, 0.96, 1.00, 1.0)
@export var color_hover: Color   = Color(0.82, 0.88, 1.00, 1.0)
@export var color_pressed: Color = Color(0.25, 0.65, 1.00, 1.0)

@export var bg_hover: Color   = Color(0.25, 0.65, 1.00, 0.08)
@export var bg_pressed: Color = Color(0.25, 0.65, 1.00, 0.16)

@export var show_focus: bool = true
@export var focus_color: Color = Color(0.25, 0.65, 1.00, 1.0)
@export var focus_margin: float = 6.0             # focus ring inset

var _hover := false
var _pressing := false

func _ready() -> void:
	pressed.connect(_on_left_click)
	flat = true
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(func(): _hover = true;  queue_redraw())
	mouse_exited.connect(func():  _hover = false; queue_redraw())
	button_down.connect(func():   _pressing = true;  queue_redraw())
	button_up.connect(func():     _pressing = false; queue_redraw())
	pressed.connect(_defocus_after_click)   # <-- add this
	resized.connect(queue_redraw)
	queue_redraw()

func _on_left_click() -> void:
	print("[CameraShotButton] Left-click → Screenshot")
	await _emit_action_once("Screenshot")
	call_deferred("release_focus") 

func _emit_action_once(action_name: String) -> void:
	var press := InputEventAction.new()
	press.action = action_name
	press.pressed = true
	Input.parse_input_event(press)

	await get_tree().process_frame

	var release := InputEventAction.new()
	release.action = action_name
	release.pressed = false
	Input.parse_input_event(release)



func _defocus_after_click() -> void:
	# Defer to let the click finish routing before removing focus.
	call_deferred("release_focus")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			print("[CameraShotButton] Right-click → ScreenshotClean")
			await _emit_action_once("ScreenshotClean")
			accept_event()                # stop propagation
			call_deferred("release_focus") # drop focus after click



func _get_state_colors() -> Dictionary:
	var pressed_state := _pressing or (toggle_mode and button_pressed)
	var col = color_normal
	var bg  = Color.TRANSPARENT
	if pressed_state:
		col = color_pressed
		bg  = bg_pressed
	elif _hover:
		col = color_hover
		bg  = bg_hover
	return {"line": col, "bg": bg}

func _draw() -> void:
	var s := size
	var min_side = min(s.x, s.y)
	var pad = min_side * 0.14
	var rect := Rect2(Vector2(pad, pad), s - Vector2(pad * 2.0, pad * 2.0))

	var cols := _get_state_colors()
	var line_col: Color = cols["line"]
	var bg_col: Color   = cols["bg"]

	# So lines look crisp on all DPIs, nudge half a pixel
	var w = max(1.0, stroke * clamp(min_side / 96.0, 0.85, 1.35))
	var half := 0.5

	# Background highlight (hover/pressed)
	if bg_col.a > 0.0:
		draw_rect(rect.grow(2.0), bg_col, true)

	# --- Camera body (rounded rectangle outline)
	var body_r = min(rect.size.x, rect.size.y) * body_radius_ratio
	_draw_round_rect_outline(rect, body_r, w, line_col)

	# --- Top "hump" / viewfinder housing (small rounded rect attached to top-left)
	var hump_w := rect.size.x * hump_width_ratio
	var hump_h := rect.size.y * hump_height_ratio
	var hump_rect := Rect2(
		Vector2(rect.position.x + w + half, rect.position.y - hump_h * 0.35),
		Vector2(hump_w - w * 2.0, hump_h)
	)
	var hump_r = body_r * 0.6
	_draw_round_rect_outline(hump_rect, hump_r, w, line_col)

	# --- Lens (outline circle)
	var center := rect.get_center() + Vector2(0, rect.size.y * 0.02)
	var lens_r = min_side * lens_ratio
	draw_arc(center, lens_r, 0.0, TAU, 48, line_col, w, true)

	# --- Shutter inner ring (subtle)
	draw_arc(center, lens_r * 0.62, 0.0, TAU, 48, line_col, max(1.0, w * 0.75), true)

	# --- Focus ring (keyboard/gamepad)
	if show_focus and has_focus():
		var f_rect := rect.grow(-focus_margin)
		_draw_focus_corners(f_rect, focus_color, max(1.0, w))

# ===== helpers =====

func _draw_round_rect_outline(r: Rect2, radius: float, width: float, col: Color) -> void:
	radius = clamp(radius, 0.0, min(r.size.x, r.size.y) * 0.5)
	var segs = max(8, int(ceil(radius)))  # enough points for smooth corners

	# Corner arc centers
	var tlc := r.position + Vector2(radius,               radius)
	var trc := r.position + Vector2(r.size.x - radius,    radius)
	var brc := r.position + Vector2(r.size.x - radius,    r.size.y - radius)
	var blc := r.position + Vector2(radius,               r.size.y - radius)

	var left   := r.position.x
	var right  := r.position.x + r.size.x
	var top    := r.position.y
	var bottom := r.position.y + r.size.y

	# 1) Straight edges between arc tangency points (meet arcs exactly)
	# Top:  from TL tangency to TR tangency
	draw_line(Vector2(tlc.x, top),    Vector2(trc.x, top),    col, width, true)
	# Right: from TR tangency to BR tangency
	draw_line(Vector2(right, trc.y),  Vector2(right, brc.y),  col, width, true)
	# Bottom: from BR tangency to BL tangency
	draw_line(Vector2(brc.x, bottom), Vector2(blc.x, bottom), col, width, true)
	# Left:  from BL tangency to TL tangency
	draw_line(Vector2(left, blc.y),   Vector2(left, tlc.y),   col, width, true)

	# 2) Quarter-circle arcs at corners (angles in radians)
	draw_arc(trc, radius, -PI/2, 0.0,  segs, col, width, true)  # top-right
	draw_arc(brc, radius, 0.0,   PI/2, segs, col, width, true)  # bottom-right
	draw_arc(blc, radius, PI/2,  PI,   segs, col, width, true)  # bottom-left
	draw_arc(tlc, radius, PI,    3*PI/2, segs, col, width, true) # top-left


func _draw_focus_corners(r: Rect2, col: Color, width: float) -> void:
	var corner = min(r.size.x, r.size.y) * 0.12
	var p := r.position
	var q := r.position + r.size

	# top-left
	draw_line(p, p + Vector2(corner, 0), col, width, true)
	draw_line(p, p + Vector2(0, corner), col, width, true)
	# top-right
	draw_line(Vector2(q.x - corner, p.y), Vector2(q.x, p.y), col, width, true)
	draw_line(Vector2(q.x, p.y), Vector2(q.x, p.y + corner), col, width, true)
	# bottom-left
	draw_line(Vector2(p.x, q.y - corner), Vector2(p.x, q.y), col, width, true)
	draw_line(Vector2(p.x, q.y), Vector2(p.x + corner, q.y), col, width, true)
	# bottom-right
	draw_line(Vector2(q.x - corner, q.y), Vector2(q.x, q.y), col, width, true)
	draw_line(Vector2(q.x, q.y - corner), Vector2(q.x, q.y), col, width, true)
