extends CanvasLayer

## Template keypad popup (introduced with the lab corridor door/keypad
## templates). Deliberate differences from elevator_panel.gd:
## - The tree is NEVER paused while this is open (see
##   OpenKeypadPanelAction.gd) so dialogue balloons on CanvasLayer 100 can
##   play over the open keypad (this panel sits on CanvasLayer 50).
##   Player movement is locked instead: the action calls
##   set_can_move(false) on open (movement is POLLED, so the Dim cannot
##   swallow it) and exit_to_world_state() in _close() re-enables it.
## - Styled as a PHYSICAL DEVICE (steel bezel, charcoal body, green LCD),
##   not in the cyan conversation-UI language - it reads as a world object
##   the player leans in on, not an interface.
## The LCD shows MAX_DIGITS fixed slots so the player knows the code
## length up front; the next empty slot doubles as the blinking cursor.
## No code validation yet: digits fill the slots, C clears, OK blinks the
## screen as a placeholder acknowledgment.

signal panel_closed

const MAX_DIGITS := 8
const SLOT_EMPTY_ALPHA := 0.4

const COLOR_BEZEL := Color(0.32, 0.33, 0.36, 1.0)
const COLOR_BEZEL_EDGE := Color(0.18, 0.19, 0.21, 1.0)
const COLOR_BODY := Color(0.13, 0.14, 0.16, 1.0)
const COLOR_BODY_EDGE := Color(0.05, 0.05, 0.06, 1.0)
const COLOR_SCREEN_BG := Color(0.04, 0.09, 0.05, 1.0)
const COLOR_SCREEN_EDGE := Color(0.02, 0.04, 0.02, 1.0)
const COLOR_SCREEN_TEXT := Color(0.45, 1.0, 0.6, 1.0)
const COLOR_KEY_BG := Color(0.22, 0.23, 0.26, 1.0)
const COLOR_KEY_BG_HOVER := Color(0.27, 0.28, 0.31, 1.0)
const COLOR_KEY_BG_PRESSED := Color(0.16, 0.17, 0.19, 1.0)
const COLOR_KEY_EDGE := Color(0.09, 0.1, 0.11, 1.0)
const COLOR_KEY_TEXT := Color(0.9, 0.9, 0.9, 1.0)
const COLOR_KEY_CLEAR_TEXT := Color(0.9, 0.55, 0.5, 1.0)
const COLOR_KEY_OK_TEXT := Color(0.55, 0.9, 0.6, 1.0)
const COLOR_ENGRAVED := Color(0.55, 0.57, 0.6, 1.0)
const COLOR_BACK_BG := Color(0.16, 0.17, 0.19, 0.92)
const COLOR_BACK_BG_HOVER := Color(0.22, 0.23, 0.26, 0.95)

const KEY_LAYOUT: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]

var _entered := ""
var _is_resolving := false
var _slots: Array[Label] = []
var _cursor_tween: Tween

@onready var _dim: ColorRect = $Dim
@onready var _center: CenterContainer = $Center
@onready var _bezel: PanelContainer = $Center/DeviceStack/Bezel
@onready var _body: PanelContainer = $Center/DeviceStack/Bezel/Body
@onready var _engraved: Label = $Center/DeviceStack/Bezel/Body/Margin/VBox/EngravedLabel
@onready var _screen: PanelContainer = $Center/DeviceStack/Bezel/Body/Margin/VBox/Screen
@onready var _screen_row: HBoxContainer = $Center/DeviceStack/Bezel/Body/Margin/VBox/Screen/ScreenRow
@onready var _button_grid: GridContainer = $Center/DeviceStack/Bezel/Body/Margin/VBox/ButtonGrid
@onready var _back_button: Button = $Center/DeviceStack/BackButton

func _ready() -> void:
	var key_size := 40
	var slot_size := 52
	var engraved_size := 26
	var back_size := 30
	if OS.has_feature("mobile"):
		key_size = 46
		slot_size = 58
		engraved_size = 30
		back_size = 34

	_style_device()

	_engraved.add_theme_font_size_override("font_size", engraved_size)
	_engraved.add_theme_color_override("font_color", COLOR_ENGRAVED)

	_build_slots(slot_size)

	# The 3-column key grid is narrower than the LCD; GridContainer
	# left-aligns inside the stretched VBox, so without an explicit
	# shrink-center it reads as off-center under the screen.
	_button_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for key_label in KEY_LAYOUT:
		var button := Button.new()
		button.text = key_label
		button.custom_minimum_size = Vector2(120, 92)
		_style_key(button, key_size, key_label)
		button.pressed.connect(_on_key_pressed.bind(key_label))
		_button_grid.add_child(button)

	_style_back_button(back_size)
	_back_button.pressed.connect(_close)

	_dim.gui_input.connect(_on_dim_gui_input)

	_refresh_screen()
	_play_open_animation()

func _style_device() -> void:
	var bezel_style := StyleBoxFlat.new()
	bezel_style.bg_color = COLOR_BEZEL
	bezel_style.border_color = COLOR_BEZEL_EDGE
	bezel_style.set_border_width_all(2)
	bezel_style.set_corner_radius_all(22)
	bezel_style.set_content_margin_all(8.0)
	bezel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	bezel_style.shadow_size = 16
	bezel_style.shadow_offset = Vector2(0.0, 6.0)
	_bezel.add_theme_stylebox_override("panel", bezel_style)

	var body_style := StyleBoxFlat.new()
	body_style.bg_color = COLOR_BODY
	body_style.border_color = COLOR_BODY_EDGE
	body_style.set_border_width_all(3)
	body_style.set_corner_radius_all(16)
	_body.add_theme_stylebox_override("panel", body_style)

	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = COLOR_SCREEN_BG
	screen_style.border_color = COLOR_SCREEN_EDGE
	screen_style.set_border_width_all(4)
	screen_style.set_corner_radius_all(8)
	screen_style.content_margin_left = 18.0
	screen_style.content_margin_right = 18.0
	screen_style.content_margin_top = 10.0
	screen_style.content_margin_bottom = 10.0
	_screen.add_theme_stylebox_override("panel", screen_style)

func _build_slots(font_size: int) -> void:
	# One fixed-width Label per code digit so the player can see the code
	# length up front. Empty slots render a dim underscore; the next slot
	# to fill blinks at full brightness (the cursor).
	for i in MAX_DIGITS:
		var slot := Label.new()
		slot.text = "_"
		slot.custom_minimum_size = Vector2(44, 64)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", font_size)
		slot.add_theme_color_override("font_color", COLOR_SCREEN_TEXT)
		_screen_row.add_child(slot)
		_slots.append(slot)

func _make_key_style(bg: Color, bottom_width: int, top_margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = COLOR_KEY_EDGE
	style.border_width_bottom = bottom_width
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = top_margin
	style.content_margin_bottom = 10.0
	return style

func _style_key(button: Button, font_size: int, key_label: String) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)

	# Thick bottom border fakes key depth; pressing thins it and pushes the
	# label down so the key visually sinks into the body.
	button.add_theme_stylebox_override("normal", _make_key_style(COLOR_KEY_BG, 6, 10.0))
	button.add_theme_stylebox_override("hover", _make_key_style(COLOR_KEY_BG_HOVER, 6, 10.0))
	button.add_theme_stylebox_override("pressed", _make_key_style(COLOR_KEY_BG_PRESSED, 2, 14.0))

	var text_color := COLOR_KEY_TEXT
	if key_label == "C":
		text_color = COLOR_KEY_CLEAR_TEXT
	elif key_label == "OK":
		text_color = COLOR_KEY_OK_TEXT
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color.lightened(0.15))
	button.add_theme_color_override("font_pressed_color", text_color.lightened(0.25))

func _make_back_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = COLOR_BEZEL_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10.0)
	return style

func _style_back_button(font_size: int) -> void:
	# A UI affordance, not a device key: it floats under the bezel so the
	# keypad itself stays a believable physical object.
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.add_theme_font_size_override("font_size", font_size)
	_back_button.add_theme_stylebox_override("normal", _make_back_style(COLOR_BACK_BG))
	_back_button.add_theme_stylebox_override("hover", _make_back_style(COLOR_BACK_BG_HOVER))
	_back_button.add_theme_stylebox_override("pressed", _make_back_style(COLOR_KEY_BG_PRESSED))
	_back_button.add_theme_color_override("font_color", COLOR_KEY_TEXT)
	_back_button.add_theme_color_override("font_hover_color", COLOR_KEY_TEXT.lightened(0.15))
	_back_button.add_theme_color_override("font_pressed_color", COLOR_KEY_TEXT.lightened(0.25))

func _refresh_screen() -> void:
	if _cursor_tween:
		_cursor_tween.kill()
	for i in MAX_DIGITS:
		var slot := _slots[i]
		if i < _entered.length():
			slot.text = _entered[i]
			slot.modulate.a = 1.0
		else:
			slot.text = "_"
			slot.modulate.a = SLOT_EMPTY_ALPHA
	if _entered.length() < MAX_DIGITS:
		var active := _slots[_entered.length()]
		active.modulate.a = 1.0
		_cursor_tween = create_tween()
		_cursor_tween.set_loops()
		_cursor_tween.tween_property(active, "modulate:a", 0.0, 0.05).set_delay(0.55)
		_cursor_tween.tween_property(active, "modulate:a", 1.0, 0.05).set_delay(0.4)

func _play_open_animation() -> void:
	_dim.modulate.a = 0.0
	_center.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.18)
	tween.tween_property(_center, "modulate:a", 1.0, 0.18)

func _on_key_pressed(key_label: String) -> void:
	if _is_resolving:
		return
	match key_label:
		"C":
			_entered = ""
		"OK":
			# Placeholder acknowledgment only - code validation is a later
			# phase (and the natural hook for Layla's balloon commentary,
			# which can play over this panel since the tree is not paused).
			_flash_screen()
		_:
			if _entered.length() < MAX_DIGITS:
				_entered += key_label
	_refresh_screen()

func _flash_screen() -> void:
	var tween := create_tween()
	tween.tween_property(_screen_row, "modulate:a", 0.15, 0.07)
	tween.tween_property(_screen_row, "modulate:a", 1.0, 0.07)
	tween.tween_property(_screen_row, "modulate:a", 0.15, 0.07)
	tween.tween_property(_screen_row, "modulate:a", 1.0, 0.07)

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close()

func _close() -> void:
	if _is_resolving:
		return
	_is_resolving = true
	if GameManager:
		# Also restores player movement (set_can_move(true)) locked by
		# OpenKeypadPanelAction on the way in.
		GameManager.exit_to_world_state()
	panel_closed.emit()
	queue_free()
