extends CanvasLayer

@onready var title = $ColorRect/MarginContainer/VBoxContainer/Title

# Tabs
@onready var tab_audio_btn = %TabAudio
@onready var tab_dialogue_btn = %TabDialogue
@onready var tab_gameplay_btn = %TabGameplay
@onready var tab_audio_content = %TabAudioContent
@onready var tab_dialogue_content = %TabDialogueContent
@onready var tab_gameplay_content = %TabGameplayContent

# Audio Tab
@onready var master_slider = %MasterSlider
@onready var master_label = %MasterLabel
@onready var master_minus = %MasterMinus
@onready var master_plus = %MasterPlus

@onready var music_slider = %MusicSlider
@onready var music_label = %MusicLabel
@onready var music_minus = %MusicMinus
@onready var music_plus = %MusicPlus

@onready var sfx_slider = %SFXSlider
@onready var sfx_label = %SFXLabel
@onready var sfx_minus = %SFXMinus
@onready var sfx_plus = %SFXPlus

# Dialogue Tab
@onready var text_scale_slider = %TextScaleSlider
@onready var text_scale_label = %TextScaleLabel
@onready var text_scale_minus = %TextScaleMinus
@onready var text_scale_plus = %TextScalePlus

@onready var instant_text_toggle = %InstantTextToggle

@onready var text_speed_slider = %TextSpeedSlider
@onready var text_speed_label = %TextSpeedLabel
@onready var text_speed_minus = %TextSpeedMinus
@onready var text_speed_plus = %TextSpeedPlus

@onready var auto_forward_toggle = %AutoForwardToggle

@onready var auto_delay_slider = %AutoDelaySlider
@onready var auto_delay_label = %AutoDelayLabel
@onready var auto_delay_minus = %AutoDelayMinus
@onready var auto_delay_plus = %AutoDelayPlus

# Gameplay Tab
@onready var assisted_mode_toggle = %AssistedModeToggle
@onready var assisted_mode_subtext = %AssistedModeSubtext

@onready var close_button = %CloseButton

var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_ui_polish()

	# Load initial values
	if GameManager:
		master_slider.value = round(GameManager.get_bus_volume("Master") * 7.0)
		music_slider.value = round(GameManager.get_bus_volume("Music") * 7.0)
		sfx_slider.value = round(GameManager.get_bus_volume("SFX") * 7.0)

		var speed_mapped = remap(GameManager.text_speed, 0.05, 0.005, 0.0, 10.0)
		text_speed_slider.value = round(speed_mapped)

		var auto_mapped = remap(GameManager.auto_time_delay, 0.125, 1.75, 1.0, 10.0)
		auto_delay_slider.value = round(auto_mapped)

		text_scale_slider.value = round((GameManager.dialogue_text_scale - 0.5) * 10.0)

		_update_instant_text_visuals(GameManager.instant_text)
		_update_auto_forward_visuals(GameManager.is_auto_playing)
		_update_assisted_toggle_visuals(GameManager.assisted_mode)

	_update_labels()

	# Connect tab buttons
	tab_audio_btn.pressed.connect(_switch_tab.bind(0))
	tab_dialogue_btn.pressed.connect(_switch_tab.bind(1))
	tab_gameplay_btn.pressed.connect(_switch_tab.bind(2))

	# Start on Audio tab
	_switch_tab(0)

	# Connect +/- buttons
	_connect_increment_buttons(master_minus, master_plus, master_slider)
	_connect_increment_buttons(music_minus, music_plus, music_slider)
	_connect_increment_buttons(sfx_minus, sfx_plus, sfx_slider)
	_connect_increment_buttons(text_scale_minus, text_scale_plus, text_scale_slider)
	_connect_increment_buttons(text_speed_minus, text_speed_plus, text_speed_slider)
	_connect_increment_buttons(auto_delay_minus, auto_delay_plus, auto_delay_slider)

	# Connect sliders & toggles
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	text_speed_slider.value_changed.connect(_on_text_speed_changed)
	auto_delay_slider.value_changed.connect(_on_auto_delay_changed)
	text_scale_slider.value_changed.connect(_on_text_scale_changed)
	instant_text_toggle.pressed.connect(_on_instant_text_pressed)
	auto_forward_toggle.pressed.connect(_on_auto_forward_pressed)
	assisted_mode_toggle.pressed.connect(_on_assisted_mode_pressed)
	close_button.pressed.connect(_on_close_pressed)

	# Close on background click (Mobile Only)
	if OS.has_feature("mobile"):
		$ColorRect.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
				_on_close_pressed()
		)

func _input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		_on_close_pressed()
	# Right-click to close (PC Only)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		get_viewport().set_input_as_handled()
		_on_close_pressed()

func _connect_increment_buttons(btn_minus: Button, btn_plus: Button, slider: HSlider):
	btn_minus.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		slider.value -= slider.step
	)
	btn_plus.pressed.connect(func():
		if SoundManager: SoundManager.play_sfx("ui_click")
		slider.value += slider.step
	)

func _switch_tab(tab_index: int):
	if SoundManager: SoundManager.play_sfx("ui_click")

	tab_audio_content.visible = (tab_index == 0)
	tab_dialogue_content.visible = (tab_index == 1)
	tab_gameplay_content.visible = (tab_index == 2)

	_style_tab_button(tab_audio_btn, tab_index == 0)
	_style_tab_button(tab_dialogue_btn, tab_index == 1)
	_style_tab_button(tab_gameplay_btn, tab_index == 2)

func _style_tab_button(btn: Button, is_active: bool):
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_top = 15 if OS.has_feature("mobile") else 10
	style.content_margin_bottom = 15 if OS.has_feature("mobile") else 10

	if is_active:
		style.bg_color = Color(0.2, 0.85, 1.0, 1.0)
		btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
		btn.add_theme_color_override("font_hover_color", Color.BLACK)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", style)

func _update_labels():
	master_label.text = "Master Volume: " + str(int(master_slider.value))
	music_label.text = "Music Volume: " + str(int(music_slider.value))
	sfx_label.text = "SFX Volume: " + str(int(sfx_slider.value))
	text_speed_label.text = "Text Speed: " + str(int(text_speed_slider.value))
	auto_delay_label.text = "Auto Wait Time: " + str(int(auto_delay_slider.value))
	text_scale_label.text = "Text Size: " + str(int(text_scale_slider.value))

func _on_master_changed(value: float):
	_update_labels()
	if GameManager: GameManager.set_bus_volume("Master", value / 7.0)

func _on_music_changed(value: float):
	_update_labels()
	if GameManager: GameManager.set_bus_volume("Music", value / 7.0)

func _on_sfx_changed(value: float):
	_update_labels()
	if GameManager: GameManager.set_bus_volume("SFX", value / 7.0)

func _on_instant_text_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager:
		GameManager.instant_text = not GameManager.instant_text
		_update_instant_text_visuals(GameManager.instant_text)

func _update_instant_text_visuals(is_on: bool):
	_style_toggle_button(instant_text_toggle, is_on)

	text_speed_slider.editable = not is_on
	var alpha = 0.4 if is_on else 1.0
	text_speed_label.modulate.a = alpha
	text_speed_slider.modulate.a = alpha
	text_speed_minus.modulate.a = alpha
	text_speed_plus.modulate.a = alpha
	text_speed_minus.disabled = is_on
	text_speed_plus.disabled = is_on

func _on_text_speed_changed(value: float):
	_update_labels()
	if GameManager:
		var new_speed = remap(value, 0.0, 10.0, 0.05, 0.005)
		GameManager.text_speed = new_speed

func _on_auto_forward_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager:
		GameManager.is_auto_playing = not GameManager.is_auto_playing
		_update_auto_forward_visuals(GameManager.is_auto_playing)

func _update_auto_forward_visuals(is_on: bool):
	_style_toggle_button(auto_forward_toggle, is_on)

	auto_delay_slider.editable = is_on
	var alpha = 1.0 if is_on else 0.4
	auto_delay_label.modulate.a = alpha
	auto_delay_slider.modulate.a = alpha
	auto_delay_minus.modulate.a = alpha
	auto_delay_plus.modulate.a = alpha
	auto_delay_minus.disabled = not is_on
	auto_delay_plus.disabled = not is_on

func _on_auto_delay_changed(value: float):
	_update_labels()
	if GameManager:
		var new_delay = remap(value, 1.0, 10.0, 0.125, 1.75)
		GameManager.auto_time_delay = new_delay

func _on_text_scale_changed(value: float):
	_update_labels()
	if GameManager:
		GameManager.dialogue_text_scale = 0.5 + (value * 0.1)

func _on_assisted_mode_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager:
		GameManager.assisted_mode = not GameManager.assisted_mode
		_update_assisted_toggle_visuals(GameManager.assisted_mode)
		if GameManager.has_method("refresh_hint_system"):
			GameManager.refresh_hint_system()

func _update_assisted_toggle_visuals(is_on: bool):
	_style_toggle_button(assisted_mode_toggle, is_on)

func _style_toggle_button(btn: Button, is_on: bool):
	var style = StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6

	if is_on:
		btn.text = "ON"
		btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1, 1.0))
		btn.add_theme_color_override("font_hover_color", Color.BLACK)
		style.bg_color = Color(0.2, 0.85, 1.0, 1.0) # Cyan
	else:
		btn.text = "OFF"
		btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		style.bg_color = Color(0.15, 0.15, 0.15, 1.0) # Dark Grey

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_stylebox_override("pressed", style)

func _on_close_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	queue_free()

func _apply_ui_polish():
	# Fonts and main text sizing
	title.add_theme_font_override("font", custom_font)
	title.add_theme_font_size_override("font_size", 72 if OS.has_feature("mobile") else 48)
	title.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0))

	var mobile_mult = 1.5 if OS.has_feature("mobile") else 1.0
	var label_size = int(28 * mobile_mult) # Increased for readability
	var toggle_size = int(24 * mobile_mult)
	var tab_size = int(30 * mobile_mult)
	var plus_minus_size = int(28 * mobile_mult)

	# Apply font to Tabs
	for btn in [tab_audio_btn, tab_dialogue_btn, tab_gameplay_btn]:
		btn.add_theme_font_override("font", custom_font)
		btn.add_theme_font_size_override("font_size", tab_size)

	# Build Square style for the +/- buttons
	var square_btn_style = StyleBoxFlat.new()
	square_btn_style.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	square_btn_style.corner_radius_top_left = 6
	square_btn_style.corner_radius_top_right = 6
	square_btn_style.corner_radius_bottom_left = 6
	square_btn_style.corner_radius_bottom_right = 6
	square_btn_style.border_width_left = 2
	square_btn_style.border_width_top = 2
	square_btn_style.border_width_right = 2
	square_btn_style.border_width_bottom = 2
	square_btn_style.border_color = Color(1.0, 1.0, 1.0, 0.0)

	var square_btn_hover = square_btn_style.duplicate()
	square_btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.9)
	square_btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.8)

	var inc_dec_buttons = [
		master_minus, master_plus, music_minus, music_plus, sfx_minus, sfx_plus,
		text_scale_minus, text_scale_plus, text_speed_minus, text_speed_plus,
		auto_delay_minus, auto_delay_plus
	]

	# Apply font to all Labels and Toggles
	var all_nodes = tab_audio_content.get_children() + tab_dialogue_content.get_children() + tab_gameplay_content.get_children()
	for child in all_nodes:
		if child is Label:
			child.add_theme_font_override("font", custom_font)
			child.add_theme_font_size_override("font_size", label_size)
			if child.name.ends_with("Label"):
				child.add_theme_color_override("font_color", Color(0.2, 0.85, 1.0, 1.0))
		elif child is HBoxContainer:
			for subchild in child.get_children():
				if subchild is Label:
					subchild.add_theme_font_override("font", custom_font)
					subchild.add_theme_font_size_override("font_size", label_size)
				elif subchild is Button:
					subchild.add_theme_font_override("font", custom_font)
					if subchild in inc_dec_buttons:
						subchild.add_theme_font_size_override("font_size", plus_minus_size)
						subchild.add_theme_stylebox_override("normal", square_btn_style)
						subchild.add_theme_stylebox_override("hover", square_btn_hover)
						subchild.add_theme_stylebox_override("focus", square_btn_hover)
						subchild.add_theme_stylebox_override("pressed", square_btn_hover)
					else:
						subchild.add_theme_font_size_override("font_size", toggle_size)

	assisted_mode_subtext.add_theme_font_size_override("font_size", int(18 * mobile_mult))

	# --- CUSTOM SLIDER STYLE (Thicker track, bigger bar) ---
	var slider_bg = StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.1, 0.12, 0.15, 1.0) # Dark solid track
	slider_bg.corner_radius_top_left = 2
	slider_bg.corner_radius_top_right = 2
	slider_bg.corner_radius_bottom_left = 2
	slider_bg.corner_radius_bottom_right = 2
	# Thicker track limits
	slider_bg.content_margin_top = 26 if OS.has_feature("mobile") else 16
	slider_bg.content_margin_bottom = 26 if OS.has_feature("mobile") else 16

	# The area left of the grabber is completely transparent so the dark track shows through
	var slider_fill = StyleBoxEmpty.new()

	# Create a custom ImageTexture for the vertical bar grabber (Taller and slightly wider)
	var grabber_width = 12 if OS.has_feature("mobile") else 8
	var grabber_height = 50 if OS.has_feature("mobile") else 32
	var grabber_img = Image.create_empty(grabber_width, grabber_height, false, Image.FORMAT_RGBA8)
	grabber_img.fill(Color(0.2, 0.85, 1.0, 1.0)) # Bright Cyan line
	var grabber_tex = ImageTexture.create_from_image(grabber_img)

	var sliders = [master_slider, music_slider, sfx_slider, text_speed_slider, auto_delay_slider, text_scale_slider]
	for s in sliders:
		s.add_theme_stylebox_override("slider", slider_bg)
		s.add_theme_stylebox_override("grabber_area", slider_fill)
		s.add_theme_stylebox_override("grabber_area_highlight", slider_fill)
		s.add_theme_icon_override("grabber", grabber_tex)
		s.add_theme_icon_override("grabber_highlight", grabber_tex)

	# Close Button Styling
	close_button.add_theme_font_override("font", custom_font)
	close_button.add_theme_font_size_override("font_size", 46 if OS.has_feature("mobile") else 28)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_top = 25 if OS.has_feature("mobile") else 10
	btn_normal.content_margin_bottom = 25 if OS.has_feature("mobile") else 10
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
