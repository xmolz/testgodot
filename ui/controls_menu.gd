extends CanvasLayer

# device-aware controls screen: keycap chips,

const ACCENT := Color("#33d9ff")
const CUSTOM_FONT := preload("res://Fonts/VarelaRound-Regular.ttf")

const ICON_LEFT_CLICK := "res://Icons/left.png"
const ICON_RIGHT_CLICK := "res://Icons/right.png"
const ICON_JOURNAL := "res://Icons/journal_icon.png"
const ICON_FORM := "res://Icons/insurance_form_icon.png"

@onready var dim_rect: ColorRect = $DimRect
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var title_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var scroll: ScrollContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ScrollContainer
@onready var scroll_margin: MarginContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ScrollContainer/ScrollMargin
@onready var rows_vbox: VBoxContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ScrollContainer/ScrollMargin/RowsVBox
@onready var close_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/CloseButton

var _is_mobile := false
var _desc_font_size := 24
var _key_font_size := 22
var _icon_height := 42.0
var _left_col_width := 330.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_is_mobile = OS.has_feature("mobile")

	if _is_mobile:
		_desc_font_size = 30
		_key_font_size = 28
		_icon_height = 52.0
		_left_col_width = 380.0

	_style_panel()
	_style_static_controls()
	_style_scrollbar()
	_build_rows()

	close_button.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		queue_free()
	)

	if _is_mobile:
		dim_rect.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				if SoundManager: SoundManager.play_sfx("ui_click")
				queue_free()
		)

func _input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		if SoundManager: SoundManager.play_sfx("ui_click")
		queue_free()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		get_viewport().set_input_as_handled()
		if SoundManager: SoundManager.play_sfx("ui_click")
		queue_free()

func _style_panel():
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 1.0)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	main_panel.add_theme_stylebox_override("panel", sb)

	var vp := get_viewport().get_visible_rect().size
	scroll.custom_minimum_size = Vector2(
		minf(900.0, vp.x * 0.82),
		minf(540.0, vp.y * 0.62)
	)

func _style_static_controls():
	title_label.add_theme_font_override("font", CUSTOM_FONT)
	title_label.add_theme_font_size_override("font_size", 52 if _is_mobile else 44)

	# ----------- close button: identical styling to the settings menu close button
	close_button.add_theme_font_override("font", CUSTOM_FONT)
	close_button.add_theme_font_size_override("font_size", 46 if _is_mobile else 28)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_top = 25 if _is_mobile else 10
	btn_normal.content_margin_bottom = 25 if _is_mobile else 10
	btn_normal.content_margin_left = 40 if _is_mobile else 30
	btn_normal.content_margin_right = 40 if _is_mobile else 30
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)
	btn_normal.anti_aliasing = false

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.8)

	close_button.add_theme_stylebox_override("normal", btn_normal)
	close_button.add_theme_stylebox_override("hover", btn_hover)
	close_button.add_theme_stylebox_override("pressed", btn_hover)
	close_button.add_theme_stylebox_override("disabled", btn_normal)
	close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.8, 1.0) if _is_mobile else Color.WHITE)
	close_button.add_theme_color_override("font_pressed_color", Color.WHITE)

func _style_scrollbar():
	# ----------------[identical to the settings menu scrollbar]
	var vbar: VScrollBar = scroll.get_v_scroll_bar()
	vbar.custom_minimum_size.x = 24 if _is_mobile else 12

	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color(0.1, 0.12, 0.15, 1.0)
	track_style.corner_radius_top_left = 4
	track_style.corner_radius_top_right = 4
	track_style.corner_radius_bottom_left = 4
	track_style.corner_radius_bottom_right = 4

	var grabber_style = StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.2, 0.85, 1.0, 0.9)
	grabber_style.corner_radius_top_left = 4
	grabber_style.corner_radius_top_right = 4
	grabber_style.corner_radius_bottom_left = 4
	grabber_style.corner_radius_bottom_right = 4

	var grabber_hl = grabber_style.duplicate()
	grabber_hl.bg_color = Color(0.2, 0.85, 1.0, 1.0)

	vbar.add_theme_stylebox_override("scroll", track_style)
	vbar.add_theme_stylebox_override("scroll_focus", track_style)
	vbar.add_theme_stylebox_override("grabber", grabber_style)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber_hl)

	scroll_margin.add_theme_constant_override("margin_right", 40 if _is_mobile else 24)

	if _is_mobile:
		scroll.scroll_deadzone = 24

func _build_rows():
	if _is_mobile:
		_add_row([_chip("Tap")], "Walk there / interact with an object")
		_add_row([_chip("Tap & Hold")], "Keep walking — drag your finger to steer")
		_add_row([_accent_label("Actions Panel")], "Pick an action, then tap an object")
		_add_row([_accent_label("Inventory")], "Select an item, then tap where to use or give it")
		_add_row([_chip("Tap Floor")], "Cancel the current action")
		_add_row([_chip("Tap")], "Continue dialogue")
		_add_row([_icon_or_chip(ICON_JOURNAL, "Journal")], "Open your journal")
		if Flags.get_level_flag("insurance_button_unlocked"):
			_add_row([_icon_or_chip(ICON_FORM, "Form")], "Open the insurance form")
		_add_row([_accent_label("Menu Button")], "Pause / options (top corner)")
	else:
		_add_row([_icon_or_chip(ICON_LEFT_CLICK, "LMB")], "Walk there / interact with an object")
		_add_row([_icon_or_chip(ICON_LEFT_CLICK, "LMB"), _plain_label("(hold)")], "Keep walking toward the cursor")
		_add_row(_movement_keys_row(), "Walk left / right")
		_add_row([_accent_label("Mouse Hover")], "Identify objects")
		_add_row([_accent_label("Actions Panel")], "Pick an action, then click an object")
		_add_row([_accent_label("Inventory")], "Select an item, then click where to use or give it")
		_add_row([_icon_or_chip(ICON_RIGHT_CLICK, "RMB")], "Cancel the current action / back out of menus")
		_add_row([_icon_or_chip(ICON_LEFT_CLICK, "LMB")], "Continue dialogue")
		_add_row([_chip("Space")], "Complete the sentence / continue dialogue")
		_add_row([_chip("Ctrl"), _plain_label("(hold)")], "Fast-forward dialogue")
		_add_row(_choice_keys_row(), "Highlight and pick dialogue choices")
		_add_row([_accent_label("Skip")], "Auto-advance dialogue you've already read")
		_add_row([_chip("H")], "Hide / show the dialogue box")
		_add_row([_accent_label("Scroll Up")], "Open the dialogue log")
		_add_row([_icon_or_chip(ICON_JOURNAL, "Journal")], "Open your journal")
		if Flags.get_level_flag("insurance_button_unlocked"):
			_add_row([_icon_or_chip(ICON_FORM, "Form")], "Open the insurance form")
		_add_row([_chip("Alt"), _plain_label("+"), _chip("Enter")], "Toggle fullscreen")
		_add_row([_chip("Esc")], "Pause / options")

func _choice_keys_row() -> Array:
	var items: Array = []
	if CUSTOM_FONT.has_char(0x2191) and CUSTOM_FONT.has_char(0x2193):
		items.append(_chip("\u2191"))
		items.append(_chip("\u2193"))
	else:
		items.append(_accent_label("Arrow Keys"))
	items.append(_plain_label("+"))
	items.append(_chip("Space"))
	return items

func _movement_keys_row() -> Array:
	var items: Array = [_chip("A"), _plain_label("/"), _chip("D"), _plain_label("or")]
	if CUSTOM_FONT.has_char(0x2190) and CUSTOM_FONT.has_char(0x2192):
		items.append(_chip("\u2190"))
		items.append(_chip("\u2192"))
	else:
		items.append(_accent_label("Arrow Keys"))
	return items

func _add_row(left_items: Array, description: String):
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var left := HBoxContainer.new()
	left.custom_minimum_size = Vector2(_left_col_width, 0)
	left.add_theme_constant_override("separation", 8)
	for item in left_items:
		left.add_child(item)
	row.add_child(left)

	var desc := Label.new()
	desc.text = description
	desc.add_theme_font_override("font", CUSTOM_FONT)
	desc.add_theme_font_size_override("font_size", _desc_font_size)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(desc)

	rows_vbox.add_child(row)

func _chip(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.18, 0.22, 1.0)
	sb.border_color = Color(0.45, 0.5, 0.58, 1.0)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 7
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", CUSTOM_FONT)
	l.add_theme_font_size_override("font_size", _key_font_size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p

func _make_icon(path: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(_icon_height, _icon_height)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t

func _icon_or_chip(path: String, fallback_text: String) -> Control:
	if ResourceLoader.exists(path):
		return _make_icon(path)
	return _chip(fallback_text)

func _accent_label(text: String) -> Label:
	var l := _plain_label(text)
	l.add_theme_color_override("font_color", ACCENT)
	return l

func _plain_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", CUSTOM_FONT)
	l.add_theme_font_size_override("font_size", _key_font_size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l
