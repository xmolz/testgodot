extends Control

func _ready():
	var tex = load("res://Icons/logo_glass_icon.png")
	if not tex:
		push_warning("Logo Cursor: Could not load image at res://Icons/logo_glass_icon.png")
		return

	var tex_rect = TextureRect.new()
	tex_rect.texture = tex

	# make the image perfectly fill
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# ensure it doesn't block any clicks (just in case)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(tex_rect)
