# hint_banner.gd — a quiet info banner for conversation choices (step 2.220).
# slides down from the top centre, swipes back up when told to. never plays a sound.
# built entirely in code and owned by conversationballoon.gd; no scene file.
extends Control

const FONT_PATH := "res://Fonts/VarelaRound-Regular.ttf"
const TOP_MARGIN := 28.0
const SLIDE_IN := 0.35
const SLIDE_OUT := 0.28

var _panel: PanelContainer
var _icon: TextureRect
var _label: Label
var _tween: Tween
var _shown := false
var _suppressed := false
var _text := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.06, 0.82)
	sb.set_corner_radius_all(22)
	sb.border_color = Color(0.4, 0.8, 0.85, 0.35)
	sb.set_border_width_all(1)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	_panel.add_child(row)

	var mobile := OS.has_feature("mobile")
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.custom_minimum_size = Vector2(40, 40) if mobile else Vector2(28, 28)
	_icon.visible = false
	row.add_child(_icon)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ResourceLoader.exists(FONT_PATH):
		_label.add_theme_font_override("font", load(FONT_PATH))
	_label.add_theme_font_size_override("font_size", 32 if mobile else 22)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	row.add_child(_label)

	_panel.visible = false


func show_hint(text: String, icon: Texture2D = null) -> void:
	if _shown and text == _text:
		return
	_text = text
	_label.text = text
	_icon.texture = icon
	_icon.visible = icon != null
	_shown = true
	if not _suppressed:
		_slide_in()


func hide_hint() -> void:
	if not _shown:
		return
	_shown = false
	if _suppressed:
		_kill_tween()
		_panel.visible = false
		return
	_slide_out()


# step 2.227: show for a few seconds, then swipe away on its own (first-visit tips etc.)
func flash_hint(text: String, icon: Texture2D = null, seconds: float = 4.0) -> void:
	show_hint(text, icon)
	var token := text
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = seconds
	add_child(t)
	t.timeout.connect(func():
		if _shown and _text == token:
			hide_hint()
		t.queue_free()
	)
	t.start()


# the balloon's Hide button: tuck the banner away with the rest of the UI, bring it back after.
func set_suppressed(value: bool) -> void:
	_suppressed = value
	if not _shown:
		return
	if value:
		_kill_tween()
		_panel.visible = false
	else:
		_slide_in()


func _slide_in() -> void:
	_kill_tween()
	_panel.visible = true
	_panel.modulate.a = 0.0
	var sz: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = sz
	var vw: float = get_viewport_rect().size.x
	_panel.position = Vector2((vw - sz.x) * 0.5, -sz.y - 12.0)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "position:y", TOP_MARGIN, SLIDE_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, SLIDE_IN * 0.7).set_trans(Tween.TRANS_SINE)


func _slide_out() -> void:
	_kill_tween()
	var h: float = _panel.size.y
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_panel, "position:y", -h - 12.0, SLIDE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "modulate:a", 0.0, SLIDE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.chain().tween_callback(func():
		if not _shown:
			_panel.visible = false
	)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
