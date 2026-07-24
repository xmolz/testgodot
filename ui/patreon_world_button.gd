# patreonworldbutton.gd — self-building "support on
class_name PatreonWorldButton
extends CanvasLayer

const PATREON_URL := "https://www.patreon.com/cw/lewgend/membership"


func _ready():
	layer = 1

	var panel = PanelContainer.new()
	add_child(panel)

	var margin = MarginContainer.new()
	panel.add_child(margin)

	var btn = TextureButton.new()
	margin.add_child(btn)

	var tex = load("res://Icons/patreon_logo.png")
	btn.texture_normal = tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.focus_mode = Control.FOCUS_NONE

	# the button is visual-only; the
	btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.tooltip_text = "Support on Patreon"

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.5)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color.WHITE
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10

	panel.add_theme_stylebox_override("panel", panel_style)

	if OS.has_feature("mobile"):
		panel.offset_left = 340
		panel.offset_top = 20
		panel.offset_right = 480
		panel.offset_bottom = 130

		margin.add_theme_constant_override("margin_top", 25)
		margin.add_theme_constant_override("margin_bottom", 25)
		margin.add_theme_constant_override("margin_left", 25)
		margin.add_theme_constant_override("margin_right", 25)
	else:
		panel.offset_left = 210
		panel.offset_top = 20
		panel.offset_right = 290
		panel.offset_bottom = 100

		margin.add_theme_constant_override("margin_top", 15)
		margin.add_theme_constant_override("margin_bottom", 15)
		margin.add_theme_constant_override("margin_left", 15)
		margin.add_theme_constant_override("margin_right", 15)

	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			if SoundManager and SoundManager.has_method("play_sfx"): SoundManager.play_sfx("ui_click")
			OS.shell_open(PATREON_URL)
	)

	panel.mouse_entered.connect(func():
		panel_style.border_color = Color(0.2, 0.85, 1.0, 1.0)
	)
	panel.mouse_exited.connect(func():
		panel_style.border_color = Color.WHITE
	)

	hide()
