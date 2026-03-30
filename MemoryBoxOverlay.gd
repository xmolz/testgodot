# MemoryBoxOverlay.gd
extends CanvasLayer

@export var all_memory_data: Array[MemoryGroupData] = []
@export var dev_cta_dialogue: DialogueResource
@onready var location_list_container: VBoxContainer = $Panel/ScrollContainer/LocationListContainer
@onready var story_button: Button = $Panel/TabContainer/StoryButton
@onready var spicy_button: Button = $Panel/TabContainer/SpicyButton
@onready var back_button: Button = $Panel/BackButton
@onready var panel: Panel = $Panel

const LocationRowScene = preload("res://LocationRow.tscn")
const ADVANCED_OVERLAY_SCENE = preload("res://AdvancedConversationOverlay.tscn")

func _ready():
	story_button.pressed.connect(_on_story_button_pressed)
	spicy_button.pressed.connect(_on_spicy_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	_populate_list(MemoryGroupData.MemoryCategory.STORY)
	
	# Hide the panel instantly before the screen even becomes visible
	panel.modulate.a = 0.0

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

			# --- THIS IS THE CRITICAL LINE, CORRECTLY INDENTED ---
			# It MUST be inside this 'if' block to access 'new_row'.
			new_row.chapter_selected.connect(_on_chapter_selected)

# --- Signal Handlers ---

func _on_story_button_pressed():
	# When the story button is pressed, rebuild the list with STORY data.
	_populate_list(MemoryGroupData.MemoryCategory.STORY)


func _on_spicy_button_pressed():
	# When the spicy button is pressed, rebuild the list with SPICY data.
	_populate_list(MemoryGroupData.MemoryCategory.SPICY)


func _on_back_button_pressed():

	if GameManager:
		GameManager.exit_to_world_state()


	print("Back button pressed, closing overlay.")
	queue_free()


func _on_chapter_selected(data: MemoryChapterData):
	if data.chapter_name.to_lower() == "chapter 1":
		var instance = ADVANCED_OVERLAY_SCENE.instantiate()
		
		# USE THE EXPORTED VARIABLE INSTEAD OF load()
		instance.dialogue_resource = dev_cta_dialogue 
		
		add_child(instance)
	else:
		print("Loading scene: ", data.scene_path_to_load)

# --- RELAXED RETRO BOOT SEQUENCE ---
func play_boot_sequence():
	# 1. Setup Initial State: Transparent, slightly smaller, slightly shifted down
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.95, 0.95)
	panel.position.y += 20.0
	panel.modulate.a = 0.0
	
	# (Future Audio Spot: A deep, ambient synth hum goes here!)
	# if SoundManager: SoundManager.play_sfx("ps2_ambient_hum")
	
	# 2. Smooth, chill tweens
	var tween = create_tween().set_parallel(true)
	
	# Phase A: Fade in slowly over 1.5 seconds
	tween.tween_property(panel, "modulate:a", 1.0, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Phase B: Gently float up and expand to full size over 2.0 seconds
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 2.0)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		
	tween.tween_property(panel, "position:y", panel.position.y - 20.0, 2.0)\
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
