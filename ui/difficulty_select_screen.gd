extends CanvasLayer

signal difficulty_chosen(is_assisted: bool)

@onready var adventure_button: Button = %AdventureButton
@onready var story_button: Button = %StoryButton

var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")

func _ready():
	_apply_button_styling(adventure_button)
	_apply_button_styling(story_button)

	adventure_button.pressed.connect(func(): _on_selection(false))
	story_button.pressed.connect(func(): _on_selection(true))

	# --- MOBILE TEXT SCALING ---
	if OS.has_feature("mobile"):
		var title = $CenterContainer/VBoxContainer/TitleLabel
		var subtitle = $CenterContainer/VBoxContainer/SubtitleLabel
		var std_desc = $CenterContainer/VBoxContainer/HBoxContainer/LeftVBox/AdventureDesc
		var std_rec = $CenterContainer/VBoxContainer/HBoxContainer/LeftVBox/AdventureRec
		var ast_desc = $CenterContainer/VBoxContainer/HBoxContainer/RightVBox/StoryDesc
		var ast_rec = $CenterContainer/VBoxContainer/HBoxContainer/RightVBox/StoryRec
		var disclaimer = $CenterContainer/VBoxContainer/DisclaimerLabel

		title.add_theme_font_size_override("font_size", 72)

		subtitle.add_theme_font_size_override("font_size", 36)
		subtitle.custom_minimum_size.x = 1200

		std_desc.add_theme_font_size_override("font_size", 32)
		std_desc.custom_minimum_size.x = 550

		std_rec.add_theme_font_size_override("font_size", 28)
		std_rec.custom_minimum_size.x = 550

		ast_desc.add_theme_font_size_override("font_size", 32)
		ast_desc.custom_minimum_size.x = 550

		ast_rec.add_theme_font_size_override("font_size", 28)
		ast_rec.custom_minimum_size.x = 550

		disclaimer.add_theme_font_size_override("font_size", 28)

func _apply_button_styling(btn: Button):
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", custom_font)
	btn.add_theme_font_size_override("font_size", 42 if OS.has_feature("mobile") else 28)

	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.content_margin_left = 50 if OS.has_feature("mobile") else 30
	normal_style.content_margin_right = 50 if OS.has_feature("mobile") else 30
	normal_style.content_margin_top = 35 if OS.has_feature("mobile") else 20
	normal_style.content_margin_bottom = 35 if OS.has_feature("mobile") else 20
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(1.0, 1.0, 1.0, 0.0)
	normal_style.anti_aliasing = false

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	hover_style.border_color = Color(0.2, 0.85, 1.0, 0.8)

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", normal_style if OS.has_feature("mobile") else hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("disabled", normal_style)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.8, 0.8, 0.8, 1.0) if OS.has_feature("mobile") else Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.8, 0.8, 0.8, 1.0))

func _on_selection(is_assisted: bool):
	if SoundManager: SoundManager.play_sfx("start_game")

	adventure_button.disabled = true
	story_button.disabled = true

	difficulty_chosen.emit(is_assisted)
