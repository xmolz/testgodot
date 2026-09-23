# keypad_prop.gd — display-only twin of ui/keypad_panel.gd for conversations.
# Same device (bezel, body, LCD slots, 3x4 keys) built the same way, minus Dim,
# Back and input. The AdvancedConversationOverlay stages it on the ActorStage with
# prop_enter() and drives it from dialogue with prop_call():
#   do prop_call("Keypad", "type_code", "07041776")   # keys animate, LCD fills
#   do prop_call("Keypad", "deny")                    # presses OK, red flash, clears
# Every animating method is a coroutine so `do` lines wait for it to finish.
# Styling is duplicated from keypad_panel.gd on purpose (that panel is untouched
# until the validation phase re-bases both on one shared device scene).
class_name KeypadProp
extends PanelContainer

signal sequence_finished

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

const PRESS_HOLD := 0.11        # key stays sunk
const PRESS_GAP := 0.16         # pause between keys while typing
const DENY_FLASHES := 4

var _entered := ""
var _slots: Array[Label] = []
var _keys: Dictionary = {}      # key label -> Button
var _cursor_tween: Tween
var _screen_style: StyleBoxFlat

@onready var _body: PanelContainer = $Body
@onready var _engraved: Label = $Body/Margin/VBox/EngravedLabel
@onready var _screen: PanelContainer = $Body/Margin/VBox/Screen
@onready var _screen_row: HBoxContainer = $Body/Margin/VBox/Screen/ScreenRow
@onready var _button_grid: GridContainer = $Body/Margin/VBox/ButtonGrid


func _ready() -> void:
	var key_size := 40
	var slot_size := 52
	var engraved_size := 26
	if OS.has_feature("mobile"):
		key_size = 46
		slot_size = 58
		engraved_size = 30

	_style_device()
	_engraved.add_theme_font_size_override("font_size", engraved_size)
	_engraved.add_theme_color_override("font_color", COLOR_ENGRAVED)
	_build_slots(slot_size)
	_button_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for key_label in KEY_LAYOUT:
		var button := Button.new()
		button.text = key_label
		button.custom_minimum_size = Vector2(120, 92)
		_style_key(button, key_size, key_label)
		# display only: never hovers, never takes clicks
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_button_grid.add_child(button)
		_keys[key_label] = button

	_refresh_screen()


# ****************************[prop API — all awaitable]
func set_code(code: String) -> void:
	_entered = code.substr(0, MAX_DIGITS)
	_refresh_screen()


func press(key_label: String) -> void:
	var button: Button = _keys.get(key_label)
	if button == null:
		push_warning("KeypadProp: no key '%s'." % key_label)
		return
	if SoundManager:
		SoundManager.play_sfx("ui_click")
	# sink the key: swap its resting style for the pressed one, then restore
	var resting: StyleBox = button.get_theme_stylebox("normal")
	button.add_theme_stylebox_override("normal", button.get_theme_stylebox("pressed"))
	await get_tree().create_timer(PRESS_HOLD).timeout
	button.add_theme_stylebox_override("normal", resting)
	match key_label:
		"C":
			_entered = ""
		"OK":
			pass
		_:
			if _entered.length() < MAX_DIGITS:
				_entered += key_label
	_refresh_screen()


func type_code(code: String) -> void:
	for ch in code:
		await press(ch)
		await get_tree().create_timer(PRESS_GAP).timeout
	sequence_finished.emit()


func deny() -> void:
	await press("OK")
	if _cursor_tween:
		_cursor_tween.kill()
	# red LCD, digits solid, flash, then wipe to empty slots
	var red := Color(1.0, 0.35, 0.3, 1.0)
	for slot in _slots:
		slot.modulate.a = 1.0
		slot.add_theme_color_override("font_color", red)
	_screen_style.bg_color = Color(0.25, 0.04, 0.04, 1.0)
	for i in DENY_FLASHES:
		_screen.modulate.a = 0.25
		await get_tree().create_timer(0.08).timeout
		_screen.modulate.a = 1.0
		await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.35).timeout
	_screen_style.bg_color = COLOR_SCREEN_BG
	for slot in _slots:
		slot.add_theme_color_override("font_color", COLOR_SCREEN_TEXT)
	_entered = ""
	_refresh_screen()
	sequence_finished.emit()


# ****************************[copied from keypad_panel.gd]
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
	add_theme_stylebox_override("panel", bezel_style)

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
	_screen_style = screen_style
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
