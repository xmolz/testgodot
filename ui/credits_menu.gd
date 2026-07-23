extends CanvasLayer

# tabbed credits screen (team /

const ACCENT := Color("#33d9ff")
const CUSTOM_FONT := preload("res://Fonts/VarelaRound-Regular.ttf")

@onready var dim_rect: ColorRect = $DimRect
@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var title_label: Label = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var tab_team_btn: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/TabsHBox/TeamTabButton
@onready var tab_patrons_btn: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/TabsHBox/PatronsTabButton
@onready var scroll: ScrollContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ScrollContainer
@onready var scroll_margin: MarginContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ScrollContainer/ScrollMargin
@onready var content_vbox: VBoxContainer = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/ScrollContainer/ScrollMargin/ContentVBox
@onready var close_button: Button = $CenterContainer/MainPanel/MarginContainer/VBoxContainer/CloseButton

var _is_mobile := false
var _role_font_size := 22
var _name_font_size := 28
var _tab_font_size := 24

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	_is_mobile = OS.has_feature("mobile")

	if _is_mobile:
		_role_font_size = 26
		_name_font_size = 34
		_tab_font_size = 30

	_style_panel()
	_style_static_controls()
	_style_scrollbar()

	tab_patrons_btn.pressed.connect(func(): _switch_tab(0))
	tab_team_btn.pressed.connect(func(): _switch_tab(1))
	_show_tab(0)

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

func _switch_tab(tab_index: int):
	if SoundManager: SoundManager.play_sfx("ui_click")
	_show_tab(tab_index)

func _show_tab(tab_index: int):
	_style_tab_button(tab_patrons_btn, tab_index == 0)
	_style_tab_button(tab_team_btn, tab_index == 1)

	for child in content_vbox.get_children():
		content_vbox.remove_child(child)
		child.queue_free()

	if tab_index == 0:
		_build_patrons_tab()
	else:
		_build_team_tab()

	scroll.scroll_vertical = 0

func _build_team_tab():
	for entry in CreditsData.TEAM:
		content_vbox.add_child(_make_label(entry["role"], _role_font_size, ACCENT))
		for person_name in entry["names"]:
			content_vbox.add_child(_make_label(person_name, _name_font_size, Color.WHITE))
		content_vbox.add_child(_make_spacer())

func _build_patrons_tab():
	content_vbox.add_child(_make_label("Thank you to our Patreon supporters!", _role_font_size, Color(0.75, 0.75, 0.75, 1.0)))
	content_vbox.add_child(_make_spacer())
	for tier in CreditsData.PATRON_TIERS:
		content_vbox.add_child(_make_label(tier["tier"], _role_font_size, ACCENT))
		for patron_name in tier["names"]:
			content_vbox.add_child(_make_label(patron_name, _name_font_size, Color.WHITE))
		content_vbox.add_child(_make_spacer())

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", CUSTOM_FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _make_spacer() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 18)
	return c

func _style_panel():
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.09, 0.11, 1.0)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	main_panel.add_theme_stylebox_override("panel", sb)

	var vp := get_viewport().get_visible_rect().size
	scroll.custom_minimum_size = Vector2(
		minf(760.0, vp.x * 0.75),
		minf(500.0, vp.y * 0.58)
	)

func _style_static_controls():
	title_label.add_theme_font_override("font", CUSTOM_FONT)
	title_label.add_theme_font_size_override("font_size", 52 if _is_mobile else 44)

	for btn in [tab_team_btn, tab_patrons_btn]:
		btn.add_theme_font_override("font", CUSTOM_FONT)
		btn.add_theme_font_size_override("font_size", _tab_font_size)

	# ******************* close button: identical styling to the settings menu close button
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

func _style_tab_button(btn: Button, is_active: bool):
	# -----------------------[identical styling to the settings menu tab buttons]
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14 if _is_mobile else 8
	style.content_margin_bottom = 14 if _is_mobile else 8

	if is_active:
		style.bg_color = Color(0.2, 0.85, 1.0, 1.0)
		btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.1, 0.1, 0.1, 1.0) if _is_mobile else Color.BLACK)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		btn.add_theme_color_override("font_hover_color", Color(0.6, 0.6, 0.6, 1.0) if _is_mobile else Color.WHITE)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("disabled", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_pressed_color", Color(0.1, 0.1, 0.1, 1.0) if is_active else Color.WHITE)

func _style_scrollbar():
	# ------------------[identical to the settings menu scrollbar]
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
