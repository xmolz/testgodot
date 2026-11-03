# res://ui/touch_verb_choice.gd
# step 2.431: on touch, a zoom-view item that can be examined OR picked up asks which, instead of guessing
# from a tap. a small card near the top of the screen, in the action bubble's language (dark panel, cyan
# edge, the object's name in cyan), with two large buttons. tapping anywhere else cancels.
# the zoom view pauses the tree, so this layer processes while paused.
extends CanvasLayer

signal chosen(verb_id: String)

const FONT_PATH := "res://Fonts/VarelaRound-Regular.ttf"
const ACCENT := Color("#33d9ff")
const PANEL_BG := Color(0.05, 0.06, 0.09, 0.96)
const BUTTON_BG := Color(0.1, 0.12, 0.18, 1.0)
const BUTTON_BG_PRESSED := Color(0.13, 0.35, 0.42, 1.0)

var _done: bool = false


## object_name: plain text (coloured here); choices: [{"id": verb id, "text": button text}, ...]
func open(object_name: String, choices: Array) -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

	# a full-screen catcher: a tap outside the card cancels
	var catcher := Control.new()
	catcher.name = "Catcher"
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_catcher_input)
	add_child(catcher)

	var card := PanelContainer.new()
	card.name = "Card"
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PANEL_BG
	card_style.set_border_width_all(2)
	card_style.border_color = Color(ACCENT, 0.8)
	card_style.set_corner_radius_all(10)
	card_style.set_content_margin_all(22.0)
	card.add_theme_stylebox_override("panel", card_style)
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_END
	card.offset_top = 96
	add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)

	var question := RichTextLabel.new()
	question.bbcode_enabled = true
	question.fit_content = true
	question.scroll_active = false
	question.autowrap_mode = TextServer.AUTOWRAP_OFF
	question.text = "[center]What do you want to do with [color=#33d9ff]%s[/color]?[/center]" % object_name
	if font:
		question.add_theme_font_override("normal_font", font)
	question.add_theme_font_size_override("normal_font_size", 30)
	question.add_theme_color_override("default_color", Color(0.92, 0.92, 0.92))
	question.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(question)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	for choice in choices:
		var btn := Button.new()
		btn.text = String(choice.get("text", choice.get("id", "")))
		btn.custom_minimum_size = Vector2(260, 96)
		btn.focus_mode = Control.FOCUS_NONE
		if font:
			btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 34)
		btn.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		btn.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95))
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		var normal := StyleBoxFlat.new()
		normal.bg_color = BUTTON_BG
		normal.set_border_width_all(2)
		normal.border_color = Color(ACCENT, 0.6)
		normal.set_corner_radius_all(8)
		var pressed := normal.duplicate()
		pressed.bg_color = BUTTON_BG_PRESSED
		btn.add_theme_stylebox_override("normal", normal)
		btn.add_theme_stylebox_override("hover", normal)
		btn.add_theme_stylebox_override("pressed", pressed)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var verb_id: String = String(choice.get("id", ""))
		btn.pressed.connect(func(): _finish(verb_id))
		row.add_child(btn)


func _on_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_finish("")


func _finish(verb_id: String) -> void:
	if _done:
		return
	_done = true
	if SoundManager and not verb_id.is_empty():
		SoundManager.play_sfx("ui_click")
	chosen.emit(verb_id)
	queue_free()
