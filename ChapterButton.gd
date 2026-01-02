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
