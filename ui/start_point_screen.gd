# res://ui/start_point_screen.gd
# step 2.423: after the difficulty screen, one more choice for a new game: play the opening (the first
# release's hospital scenes), or start where the demo ended, with the memory box ready to use.
# built in code (no scene); the look is difficulty_select_screen.gd's.
extends CanvasLayer

signal start_point_chosen(skip_to_demo_end: bool)

const FONT_PATH := "res://Fonts/VarelaRound-Regular.ttf"

const TITLE := "WHERE DO YOU WANT TO START?"
const BEGIN_BUTTON := "FROM THE BEGINNING"
const BEGIN_DESC := "Wake up in the hospital and play the opening: the room, the people in it, and how the memory box works."
const SKIP_BUTTON := "WHERE THE DEMO ENDED"
const SKIP_DESC := "Skip the opening. You've met everyone, the pass is in your pocket, and the memory box is ready to use."
const FOOT := "Played the demo already? The second option picks up right after it."

var _chosen: bool = false
var _font: Font = null


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	var mobile := OS.has_feature("mobile")

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 40 if mobile else 28)
	center.add_child(column)

	column.add_child(_label(TITLE, 56 if mobile else 40, Color(0.84, 0.95, 0.57), 0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 60 if mobile else 40)
	column.add_child(row)
	row.add_child(_option(BEGIN_BUTTON, BEGIN_DESC, false, mobile))
	row.add_child(_option(SKIP_BUTTON, SKIP_DESC, true, mobile))

	column.add_child(_label(FOOT, 26 if mobile else 18, Color(0.6, 0.6, 0.6), 0))


func _option(button_text: String, desc: String, skip: bool, mobile: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size.x = 550 if mobile else 440
	var btn := Button.new()
	btn.text = button_text
	_style_button(btn, mobile)
	btn.pressed.connect(func(): _choose(skip))
	box.add_child(btn)
	box.add_child(_label(desc, 30 if mobile else 20, Color(0.8, 0.8, 0.8), 550 if mobile else 440))
	return box


func _label(text: String, size: int, color: Color, width: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if _font:
		l.add_theme_font_override("font", _font)
	if width > 0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


# the difficulty screen's button look (difficulty_select_screen.gd _apply_button_styling)
func _style_button(btn: Button, mobile: bool) -> void:
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 42 if mobile else 28)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	normal_style.set_corner_radius_all(8)
	normal_style.content_margin_left = 50 if mobile else 30
	normal_style.content_margin_right = 50 if mobile else 30
	normal_style.content_margin_top = 35 if mobile else 20
	normal_style.content_margin_bottom = 35 if mobile else 20
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color(1.0, 1.0, 1.0, 0.0)
	normal_style.anti_aliasing = false
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	hover_style.border_color = Color(0.2, 0.85, 1.0, 0.8)
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", normal_style if mobile else hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("disabled", normal_style)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.8, 1.0) if mobile else Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.8, 1.0))


func _choose(skip: bool) -> void:
	if _chosen:
		return
	_chosen = true
	if SoundManager:
		SoundManager.play_sfx("start_game")
	for btn in find_children("*", "Button", true, false):
		btn.disabled = true
	start_point_chosen.emit(skip)
