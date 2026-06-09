# ChapterButton.gd
extends Button

# This signal is emitted when the button is pressed, sending its own data along.
signal chapter_selected(data: MemoryChapterData)

# --- NODE REFERENCES ---
@onready var chapter_name_label: Label = $MarginContainer/VBoxContainer/Label
@onready var chapter_image_rect: TextureRect = $MarginContainer/VBoxContainer/TextureRect

# --- DATA ---
var chapter_data: MemoryChapterData
func _ready():
	# Connect our own "pressed" signal to a handler function.
	self.pressed.connect(_on_pressed)

	# --- TOUCH SCROLL FIX ---
	# Buttons default to STOP, which blocks the ScrollContainer from seeing swipes.
	# Changing this to PASS allows silky smooth native touch scrolling!
	self.mouse_filter = Control.MOUSE_FILTER_PASS

	# --- MOBILE SCALING FOR CHAPTER BUTTON ---
	if OS.has_feature("mobile"):
		self.custom_minimum_size = Vector2(350, 260)
		chapter_name_label.add_theme_font_size_override("font_size", 32)
		# Provide 80 pixels of vertical space so the text easily fits without clipping
		chapter_name_label.custom_minimum_size.y = 80

func _on_pressed():
	# When this button is pressed, emit our custom signal,
	# passing our own chapter_data along with it.
	emit_signal("chapter_selected", chapter_data)

## This function takes MemoryChapterData and configures the button's UI.
func populate(data: MemoryChapterData):
	self.chapter_data = data

	# --- 1. SET THE VISUALS ---
	chapter_name_label.text = chapter_data.chapter_name
	chapter_image_rect.texture = chapter_data.chapter_image

	# --- 2. HANDLE LOCKED/UNLOCKED STATE ---
	# Check if the chapter has a flag that needs to be checked.
	if not chapter_data.unlock_flag.is_empty():
		# Ask the GameManager if the flag is true or false.
		var is_unlocked = GameManager.get_game_flag(chapter_data.unlock_flag)

		if not is_unlocked:
			# If the chapter is locked, make it look disabled.
			self.disabled = true
			# Modulate makes the button and its children look grayed out.
			self.modulate = Color(0.5, 0.5, 0.5, 1.0)

	# If there's no unlock_flag, the button is unlocked by default,
	# so we don't need to do anything.
