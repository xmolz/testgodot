# LocationRow.gd
extends HBoxContainer

# --- NODE REFERENCES ---
# We need to get references to the parts of our scene that we want to change.

# Left side (Location Info)
@onready var location_name_label: Label = $PanelContainer/VBoxContainer/Label
@onready var location_image_rect: TextureRect = $PanelContainer/VBoxContainer/TextureRect

# Right side (Chapters)
@onready var chapter_list_container: HBoxContainer = $PanelContainer2/HBoxContainer/Panel/ChapterListContainer
@onready var left_arrow_button: Button = $PanelContainer2/HBoxContainer/LeftArrowButton
@onready var right_arrow_button: Button = $PanelContainer2/HBoxContainer/RightArrowButton

# --- PRELOADS ---
# We need to load the ChapterButton scene so we can create instances of it.
const ChapterButtonScene = preload("res://ChapterButton.tscn") # <-- IMPORTANT: Verify this path!

# --- DATA ---
# This variable will hold the MemoryGroupData resource for this row.
var memory_data: MemoryGroupData


func _ready():
	# Connect the arrow buttons' "pressed" signals to functions in this script.
	left_arrow_button.pressed.connect(_on_left_arrow_pressed)
	right_arrow_button.pressed.connect(_on_right_arrow_pressed)

	# TODO: We will add the logic for the arrow buttons later.
	pass


# --- TODO: We will implement these functions in a later step ---
func _on_left_arrow_pressed():
	print("Left Arrow Pressed")

func _on_right_arrow_pressed():
	print("Right Arrow Pressed")

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
