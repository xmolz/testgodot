# MemoryBoxOverlay.gd
extends CanvasLayer

## EXPORTED VARIABLES
## Drag all of your MemoryGroupData (.tres) files into this array in the Inspector.
@export var all_memory_data: Array[MemoryGroupData] = []

## NODE REFERENCES
@onready var location_list_container: VBoxContainer = $Panel/ScrollContainer/VBoxContainer
@onready var story_button: Button = $Panel/HBoxContainer/StoryButton
@onready var spicy_button: Button = $Panel/HBoxContainer/SpicyButton
@onready var back_button: Button = $Panel/Button # Or whatever you named your back button

## PRELOADS
const LocationRowScene = preload("res://LocationRow.tscn") # <-- IMPORTANT: Verify this path!


func _ready():
	# Connect the buttons to their handler functions
	story_button.pressed.connect(_on_story_button_pressed)
	spicy_button.pressed.connect(_on_spicy_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	# When the scene opens, show the "Story" category by default.
	_populate_list(MemoryGroupData.MemoryCategory.STORY)


## This is the main function that builds the UI.
func _populate_list(category_to_show: MemoryGroupData.MemoryCategory):
	# First, clear any location rows that are already there.
	for child in location_list_container.get_children():
		child.queue_free()

	# Now, loop through all of our data files.
	for memory_group in all_memory_data:
		# Check if the data's category matches the tab we want to show.
		if memory_group.category == category_to_show:
			# If it matches, create a new LocationRow instance.
			var new_row = LocationRowScene.instantiate()
			# Add it to our VBoxContainer.
			location_list_container.add_child(new_row)
			# And tell the new row to populate itself with this data.
			new_row.populate(memory_group)


# --- Signal Handlers ---

func _on_story_button_pressed():
	# When the story button is pressed, rebuild the list with STORY data.
	_populate_list(MemoryGroupData.MemoryCategory.STORY)


func _on_spicy_button_pressed():
	# When the spicy button is pressed, rebuild the list with SPICY data.
	_populate_list(MemoryGroupData.MemoryCategory.SPICY)


func _on_back_button_pressed():
	# When the back button is pressed, close this overlay.
	# We can add a GameManager call here later if needed.
	print("Back button pressed, closing overlay.")
	queue_free()
