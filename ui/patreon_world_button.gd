# PatreonWorldButton.gd — self-building "Support on Patreon" world-UI button.
class_name PatreonWorldButton
extends CanvasLayer

const PATREON_URL := "https://www.patreon.com/cw/lewgend"


func _ready():
	layer = 1

	var btn = Button.new()
	add_child(btn)

	var tex = load("res://Icons/patreon_logo.png")
	if tex:
		var img = tex.get_image()
		if img:
			img.resize(48, 48, Image.INTERPOLATE_BILINEAR)
			tex = ImageTexture.create_from_image(img)
		btn.icon = tex

	btn.text = " Support on Patreon"
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_constant_override("h_separation", 10)
	btn.add_theme_font_override("font", preload("res://Fonts/VarelaRound-Regular.ttf"))
	btn.add_theme_font_size_override("font_size", 20)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.6)
	btn_normal.corner_radius_top_left = 10
	btn_normal.corner_radius_top_right = 10
	btn_normal.corner_radius_bottom_left = 10
	btn_normal.corner_radius_bottom_right = 10
	btn_normal.content_margin_left = 15
	btn_normal.content_margin_right = 20
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10
	btn_normal.border_width_left = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.8)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.8)

	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("focus", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_hover)

	btn.position = Vector2(20, 20)
	if OS.has_feature("mobile"):
		btn.position = Vector2(40, 40)
		btn.add_theme_font_size_override("font_size", 28)

	btn.pressed.connect(func():
		if SoundManager and SoundManager.has_method("play_sfx"): SoundManager.play_sfx("ui_click")
		OS.shell_open(PATREON_URL)
	)

	hide()
