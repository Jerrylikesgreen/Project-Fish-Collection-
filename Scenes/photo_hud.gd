extends Control



@onready var frame_opt: OptionButton = %OptionButton
@onready var tl_opt: OptionButton      = %TL
@onready var tr_opt: OptionButton      = %TR
@onready var bl_opt: OptionButton      = %BL
@onready var br_opt: OptionButton      = %BR
@onready var include_ui_check: CheckButton = %IncludeUICheck
@onready var shot_btn: Button          = %ShotBtn
@onready var close_btn: Button         = %CloseBtn

var _frame_names: PackedStringArray = []
var _sticker_names: PackedStringArray = []

func _ready() -> void:

	# populate stickers (add "None" at top)
	_sticker_names.clear()
	_sticker_names.append("None")
	for k in ScreenshotManager.sticker_assets.keys():
		_sticker_names.append(String(k))
	_sticker_names.sort()

	for opt in [tl_opt, tr_opt, bl_opt, br_opt]:
		opt.clear()
		for i in range(_sticker_names.size()):
			opt.add_item(_sticker_names[i], i)
		opt.select(0)  # None

	# default preview
	if _frame_names.size() > 0:
		frame_opt.select(0)
		_on_frame_changed(0)

	frame_opt.item_selected.connect(_on_frame_changed)
	tl_opt.item_selected.connect(_on_stickers_changed)
	tr_opt.item_selected.connect(_on_stickers_changed)
	bl_opt.item_selected.connect(_on_stickers_changed)
	br_opt.item_selected.connect(_on_stickers_changed)

	shot_btn.pressed.connect(_on_take_photo)
	close_btn.pressed.connect(_on_close)

	visible = false  # open via your input or a button

func _on_frame_changed(_idx: int) -> void:
	var name := frame_opt.get_item_text(frame_opt.get_selected_id())
	# guard: if key not in dict, preview none
	if not ScreenshotManager.frame_assets.has(name):
		ScreenshotManager.preview_frame("none")
	else:
		ScreenshotManager.preview_frame(name)

func _on_stickers_changed(_idx: int) -> void:
	var stickers := _collect_sticker_list()
	ScreenshotManager.preview_stickers(stickers)

func _collect_sticker_list() -> Array:
	var arr: Array = []
	var sels := [tl_opt, tr_opt, bl_opt, br_opt]
	for opt in sels:
		var txt = opt.get_item_text(opt.get_selected_id())
		if txt != "None":
			arr.append(txt)
		else:
			# keep array position with an empty string so TL/TR/BL/BR stay aligned
			arr.append("")
	return arr

func _on_take_photo() -> void:
	var stickers := _collect_sticker_list()
	# remove trailing empties to keep your autoload logic simple
	while stickers.size() > 0 and String(stickers[stickers.size() - 1]) == "":
		stickers.pop_back()

	# apply current preview to be safe, then shoot
	ScreenshotManager.preview_stickers(stickers)
	var name := frame_opt.get_item_text(frame_opt.get_selected_id())
	if ScreenshotManager.frame_assets.has(name):
		ScreenshotManager.preview_frame(name)
	else:
		ScreenshotManager.preview_frame("none")

	var include_ui := include_ui_check.button_pressed
	await ScreenshotManager.shoot_from_preview(include_ui)

func _on_close() -> void:
	ScreenshotManager.clear_preview()
	visible = false

func open() -> void:
	visible = true

func toggle() -> void:
	visible = not visible
	if not visible:
		ScreenshotManager.clear_preview()
