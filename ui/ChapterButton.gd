# chapterbutton.gd
extends Button

# this signal is emitted when
signal chapter_selected(data: MemoryChapterData)

# ********** node references
@onready var chapter_name_label: Label = $MarginContainer/VBoxContainer/Label
@onready var chapter_image_rect: TextureRect = $MarginContainer/VBoxContainer/TextureRect

# ******************* data
var chapter_data: MemoryChapterData
func _ready():
	# connect our own "pressed" signal to a handler function.
	self.pressed.connect(_on_pressed)

	# ************************[touch scroll fix]
	# buttons default to stop, which
	# changing this to pass allows
	self.mouse_filter = Control.MOUSE_FILTER_PASS

	# --------------(mobile scaling for chapter button)
	if OS.has_feature("mobile"):
		self.custom_minimum_size = Vector2(240, 175)
		chapter_name_label.add_theme_font_size_override("font_size", 24)
		# provide 56 pixels of vertical
		chapter_name_label.custom_minimum_size.y = 56

func _on_pressed():
	# when this button is pressed, emit our custom signal,
	# passing our own chapter_data along with it.
	emit_signal("chapter_selected", chapter_data)

# this function takes memorychapterdata and
func populate(data: MemoryChapterData):
	self.chapter_data = data

	# ////////////////////////(1. set the visuals)
	chapter_name_label.text = chapter_data.chapter_name
	chapter_image_rect.texture = chapter_data.chapter_image

	# if chapter is SPICY, apply pinkish-red styling
	if chapter_data.chapter_type == MemoryChapterData.ChapterType.SPICY:
		var normal_style = get_theme_stylebox("normal").duplicate()
		var hover_style = get_theme_stylebox("hover").duplicate()
		
		var spicy_color = Color(0.910, 0.329, 0.494)
		normal_style.border_color = spicy_color
		
		hover_style.border_color = spicy_color
		hover_style.bg_color = Color(spicy_color.r, spicy_color.g, spicy_color.b, 0.1)
		
		add_theme_stylebox_override("normal", normal_style)
		add_theme_stylebox_override("hover", hover_style)
		
		chapter_name_label.add_theme_color_override("font_color", spicy_color.lerp(Color.WHITE, 0.3))

	# ------------------- 2. handle locked/unlocked state
	# check if the chapter has
	if not chapter_data.unlock_flag.is_empty():
		# ask the gamemanager if the flag is true or false.
		var is_unlocked = Flags.get_game_flag(chapter_data.unlock_flag)

		if not is_unlocked:
			# if the chapter is locked, make it look disabled.
			self.disabled = true
			# modulate makes the button and
			self.modulate = Color(0.5, 0.5, 0.5, 1.0)

	# if there's no unlock_flag, the
	# o we don't need to do anything.
