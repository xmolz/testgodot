extends CanvasLayer

@onready var title = $ColorRect/MarginContainer/VBoxContainer/Title
@onready var master_slider = $ColorRect/MarginContainer/VBoxContainer/MasterSlider
@onready var master_val = $ColorRect/MarginContainer/VBoxContainer/MasterHBox/MasterVal
@onready var music_slider = $ColorRect/MarginContainer/VBoxContainer/MusicSlider
@onready var music_val = $ColorRect/MarginContainer/VBoxContainer/MusicHBox/MusicVal
@onready var sfx_slider = $ColorRect/MarginContainer/VBoxContainer/SFXSlider
@onready var sfx_val = $ColorRect/MarginContainer/VBoxContainer/SFXHBox/SFXVal
@onready var instant_text_toggle = $ColorRect/MarginContainer/VBoxContainer/InstantTextHBox/InstantTextToggle
@onready var text_speed_margin = $ColorRect/MarginContainer/VBoxContainer/TextSpeedMargin
@onready var text_speed_slider = $ColorRect/MarginContainer/VBoxContainer/TextSpeedMargin/TextSpeedContainer/TextSpeedSlider
@onready var text_speed_val = $ColorRect/MarginContainer/VBoxContainer/TextSpeedMargin/TextSpeedContainer/TextSpeedHBox/TextSpeedVal
@onready var close_button = $ColorRect/MarginContainer/VBoxContainer/CloseButton

var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_ui_polish()

	if GameManager:
		master_slider.value = round(GameManager.get_bus_volume("Master") * 10.0)
		music_slider.value = round(GameManager.get_bus_volume("Music") * 10.0)
		sfx_slider.value = round(GameManager.get_bus_volume("SFX") * 10.0)

		var speed_mapped = remap(GameManager.text_speed, 0.05, 0.005, 0.0, 10.0)
		text_speed_slider.value = round(speed_mapped)

		_update_toggle_visuals(GameManager.instant_text)

	_update_labels()

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	text_speed_slider.value_changed.connect(_on_text_speed_changed)
	instant_text_toggle.pressed.connect(_on_instant_text_pressed)
	close_button.pressed.connect(_on_close_pressed)

	$ColorRect.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			_on_close_pressed()
	)

func _input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_close_pressed()

func _update_labels():
	master_val.text = str(master_slider.value)
	music_val.text = str(music_slider.value)
	sfx_val.text = str(sfx_slider.value)
	text_speed_val.text = str(text_speed_slider.value)

func _on_master_changed(value: float):
	master_val.text = str(value)
	if GameManager: GameManager.set_bus_volume("Master", value / 10.0)

func _on_music_changed(value: float):
	music_val.text = str(value)
	if GameManager: GameManager.set_bus_volume("Music", value / 10.0)

func _on_sfx_changed(value: float):
	sfx_val.text = str(value)
	if GameManager: GameManager.set_bus_volume("SFX", value / 10.0)

func _on_instant_text_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager:
		GameManager.instant_text = not GameManager.instant_text
		_update_toggle_visuals(GameManager.instant_text)

func _update_toggle_visuals(is_on: bool):
	text_speed_margin.visible = not is_on

	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	if is_on:
		instant_text_toggle.text = "ON"
		instant_text_toggle.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
		instant_text_toggle.add_theme_color_override("font_hover_color", Color.BLACK)
		style.bg_color = Color(0.2, 0.85, 1.0, 1.0) # Cyan
	else:
		instant_text_toggle.text = "OFF"
		instant_text_toggle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		instant_text_toggle.add_theme_color_override("font_hover_color", Color.WHITE)
		style.bg_color = Color(0.15, 0.15, 0.15, 1.0) # Dark Grey

	instant_text_toggle.add_theme_stylebox_override("normal", style)
	instant_text_toggle.add_theme_stylebox_override("hover", style)
	instant_text_toggle.add_theme_stylebox_override("focus", style)
	instant_text_toggle.add_theme_stylebox_override("pressed", style)

func _on_text_speed_changed(value: float):
	text_speed_val.text = str(value)
	if GameManager:
		var new_speed = remap(value, 0.0, 10.0, 0.05, 0.005)
		GameManager.text_speed = new_speed

func _on_close_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	queue_free()

func _apply_ui_polish():
	title.add_theme_font_override("font", custom_font)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0))

	instant_text_toggle.add_theme_font_override("font", custom_font)
	instant_text_toggle.add_theme_font_size_override("font_size", 20)

	for child in $ColorRect/MarginContainer/VBoxContainer.get_children():
		if child is HBoxContainer:
			for subchild in child.get_children():
				if subchild is Label:
					subchild.add_theme_font_override("font", custom_font)
					# Main labels get 24, TextSpeed gets 20 below
					subchild.add_theme_font_size_override("font_size", 24)
					if subchild.name.ends_with("Val"):
						subchild.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0))

	# Specifically scale down the sub-settings
	var speed_hbox = $ColorRect/MarginContainer/VBoxContainer/TextSpeedMargin/TextSpeedContainer/TextSpeedHBox
	for subchild in speed_hbox.get_children():
		if subchild is Label:
			subchild.add_theme_font_override("font", custom_font)
			subchild.add_theme_font_size_override("font_size", 20)
			if subchild.name.ends_with("Val"):
				subchild.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0))

	var slider_bg = StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	slider_bg.corner_radius_top_left = 4
	slider_bg.corner_radius_top_right = 4
	slider_bg.corner_radius_bottom_left = 4
	slider_bg.corner_radius_bottom_right = 4
	slider_bg.content_margin_top = 8
	slider_bg.content_margin_bottom = 8

	var slider_fill = StyleBoxFlat.new()
	slider_fill.bg_color = Color(0.2, 0.85, 1.0, 1.0)
	slider_fill.corner_radius_top_left = 4
	slider_fill.corner_radius_bottom_left = 4
	slider_fill.content_margin_top = 8
	slider_fill.content_margin_bottom = 8

	var sliders = [master_slider, music_slider, sfx_slider, text_speed_slider]
	for s in sliders:
		s.add_theme_stylebox_override("slider", slider_bg)
		s.add_theme_stylebox_override("grabber_area", slider_fill)
		s.add_theme_stylebox_override("grabber_area_highlight", slider_fill)

	close_button.add_theme_font_override("font", custom_font)
	close_button.add_theme_font_size_override("font_size", 28)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.8)

	close_button.add_theme_stylebox_override("normal", btn_normal)
	close_button.add_theme_stylebox_override("hover", btn_hover)
	close_button.add_theme_stylebox_override("focus", btn_hover)
	close_button.add_theme_stylebox_override("pressed", btn_hover)
	close_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	close_button.add_theme_color_override("font_hover_color", Color.WHITE)
	close_button.add_theme_color_override("font_pressed_color", Color.WHITE)
