# LocationRow.gd
extends HBoxContainer
# This signal relays the message from a ChapterButton up to the main overlay.
signal chapter_selected(data: MemoryChapterData)

# --- NODE REFERENCES ---
# We need to get references to the parts of our scene that we want to change.
@onready var location_name_label: Label = $LocationInfoPanel/VBoxContainer/Label
@onready var location_image_rect: TextureRect = $LocationInfoPanel/VBoxContainer/TextureRect
@onready var chapter_list_container: HBoxContainer = $ChaptersAreaPanel/HBoxContainer/ViewportPanel/ChapterListContainer
@onready var left_arrow_button: Button = $ChaptersAreaPanel/HBoxContainer/LeftArrowButton
@onready var right_arrow_button: Button = $ChaptersAreaPanel/HBoxContainer/RightArrowButton

# --- PRELOADS ---
# We need to load the ChapterButton scene so we can create instances of it.
const ChapterButtonScene = preload("res://ChapterButton.tscn") # <-- IMPORTANT: Verify this path!

# --- SCROLLING VARIABLES ---
@export var scroll_speed: float = 0.5 # How long the scroll animation takes.
var _target_scroll_x: float = 0.0 # The target X position for our container.
var _is_scrolling: bool = false   # A flag to prevent spamming the scroll buttons.

# --- DATA ---
# This variable will hold the MemoryGroupData resource for this row.
var memory_data: MemoryGroupData


func _ready():
	# Connect the arrow buttons' "pressed" signals to functions in this script.
	left_arrow_button.pressed.connect(_on_left_arrow_pressed)
	right_arrow_button.pressed.connect(_on_right_arrow_pressed)


## This function takes a MemoryGroupData resource and configures the row's UI.
func populate(data: MemoryGroupData):
	# Store the data for later use.
	self.memory_data = data

	# --- 1. SET LOCATION INFO ---
	# Set the text and texture for the left-side panel.
	location_name_label.text = memory_data.group_name
	location_image_rect.texture = memory_data.group_image

	# --- 2. CLEAR ANY EXISTING CHAPTERS ---
	# This is important for when we switch tabs (Story/Spicy).
	for child in chapter_list_container.get_children():
		child.queue_free()

	# --- 3. CREATE NEW CHAPTER BUTTONS ---
	# Loop through the chapter data in our resource.
	for chapter_data in memory_data.chapters:
		# Create a new instance of our template scene.
		var new_chapter_button = ChapterButtonScene.instantiate()
		# Add the new button to our HBoxContainer.
		chapter_list_container.add_child(new_chapter_button)
		# Call the populate function on the new button and pass it the data.
		new_chapter_button.populate(chapter_data)

		# Listen for the button's signal and connect it to a relay function.
		new_chapter_button.chapter_selected.connect(_on_chapter_button_selected)

	# After creating the buttons, update the arrow visibility.
	_update_arrow_state()


func _update_arrow_state():
	# Wait until the next idle frame. This is more reliable than the physics frame
	# for UI size calculations after adding new nodes.
	await get_tree().process_frame

	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	var viewport_width = viewport_panel.size.x
	var content_width = chapter_list_container.size.x

	# --- CORE LOGIC FIX ---
	# The maximum distance the content can scroll is its total width minus the visible width.
	# We use max(0, ...) to ensure this isn't negative if the content is smaller.
	var max_scroll = max(0.0, content_width - viewport_width)

	# Disable the left button if we are at the beginning (or can't scroll at all).
	# Use a small tolerance to handle floating point inaccuracies.
	left_arrow_button.disabled = (_target_scroll_x >= -1.0)

	# Disable the right button if we have reached the end (or can't scroll at all).
	right_arrow_button.disabled = (_target_scroll_x <= -max_scroll + 1.0)

func _on_left_arrow_pressed():
	# Don't do anything if we are already scrolling or the button is disabled.
	if _is_scrolling or left_arrow_button.disabled: return

	var viewport_width = $ChaptersAreaPanel/HBoxContainer/ViewportPanel.size.x
	# Move the target position to the right (less negative) by one "page".
	_target_scroll_x = min(0.0, _target_scroll_x + viewport_width)
	_animate_scroll()

func _on_chapter_button_selected(data: MemoryChapterData):
	# When we hear a signal from a chapter button, we just pass it up the chain.
	emit_signal("chapter_selected", data)

func _on_right_arrow_pressed():
	# Don't do anything if we are already scrolling or the button is disabled.
	if _is_scrolling or right_arrow_button.disabled: return

	var viewport_width = $ChaptersAreaPanel/HBoxContainer/ViewportPanel.size.x
	var content_width = chapter_list_container.size.x

	# Only calculate max_scroll if there's actually something to scroll.
	var max_scroll = 0.0
	if content_width > viewport_width:
		max_scroll = content_width - viewport_width

	# Move the target position to the left (more negative) by one "page".
	# Use max() to ensure we don't scroll past the end of the content.
	_target_scroll_x = max(-max_scroll, _target_scroll_x - viewport_width)
	_animate_scroll()


## This function performs the actual animation.
func _animate_scroll():
	_is_scrolling = true

	# Create a new Tween (Godot's animation tool).
	var tween = create_tween()
	# Tell it to animate the 'position:x' property of our chapter container.
	tween.tween_property(chapter_list_container, "position:x", _target_scroll_x, scroll_speed)\
		 .set_trans(Tween.TRANS_SINE)\
		 .set_ease(Tween.EASE_OUT)

	# When the animation is finished, update state and button visibility.
	await tween.finished
	_is_scrolling = false
	_update_arrow_state()
