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

	# --- MOBILE SCALING FOR MEMORY BOX MAIN UI ---
	if OS.has_feature("mobile"):
		# Perfectly center the Title
		var title = $Panel/TitleLabel
		title.add_theme_font_size_override("font_size", 64)
		title.anchor_left = 0.0
		title.anchor_right = 1.0
		title.offset_left = 0
		title.offset_right = 0

		# Make the Back button much larger
		back_button.add_theme_font_size_override("font_size", 72)
		back_button.custom_minimum_size = Vector2(100, 100)

		# Scale up the tabs
		story_button.add_theme_font_size_override("font_size", 36)
		story_button.custom_minimum_size = Vector2(200, 80)

		spicy_button.add_theme_font_size_override("font_size", 36)
		spicy_button.custom_minimum_size = Vector2(200, 80)

		# Perfectly center the tabs under the title
		var tabs = $Panel/TabContainer
		tabs.anchor_left = 0.0
		tabs.anchor_right = 1.0
		tabs.offset_left = 0
		tabs.offset_right = 0
		tabs.alignment = BoxContainer.ALIGNMENT_CENTER

		# Push the tabs down slightly to create a gap below the main title
		tabs.anchor_top = 0.15
		tabs.anchor_bottom = 0.25

		# Push the chapter list further down to create a gap between it and the tabs
		var scroll = $Panel/ScrollContainer
		scroll.anchor_top = 0.32

	_populate_list(MemoryGroupData.MemoryCategory.STORY)

	# Hide the panel instantly before the screen even becomes visible
	panel.modulate.a = 0.0

	call_deferred("_restore_patreon_button")

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
	if SoundManager: SoundManager.play_sfx("ui_click")
	_populate_list(MemoryGroupData.MemoryCategory.STORY)


func _on_spicy_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	_populate_list(MemoryGroupData.MemoryCategory.SPICY)


func _on_back_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager:
		GameManager.exit_to_world_state()

	print("Back button pressed, closing overlay.")
	queue_free()


func _on_chapter_selected(data: MemoryChapterData):
	if data.chapter_name.to_lower() == "chapter 1":
		# Clear the persistent Patreon button if they replay the scene
		var old_btn = get_node_or_null("PersistentPatreonBtn")
		if is_instance_valid(old_btn):
			old_btn.queue_free()

		var instance = ADVANCED_OVERLAY_SCENE.instantiate()
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

func _restore_patreon_button():
	if not GameManager:
		return
	if not GameManager.get_current_level_flag("dev_cta_completed"):
		return
	var existing = get_node_or_null("PersistentPatreonBtn")
	if is_instance_valid(existing):
		return

	var tex = load("res://Icons/patreon_logo.png")
	if not tex:
		return

	var img = tex.get_image()
	if img:
		img.resize(96, 96, Image.INTERPOLATE_BILINEAR)
		tex = ImageTexture.create_from_image(img)

	var custom_font = load("res://Fonts/VarelaRound-Regular.ttf")

	var btn = Button.new()
	btn.name = "PersistentPatreonBtn"
	btn.text = " Support on Patreon"
	btn.icon = tex
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_constant_override("h_separation", 18)

	btn.add_theme_font_override("font", custom_font)
	btn.add_theme_font_size_override("font_size", 44 if OS.has_feature("mobile") else 36)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	btn_normal.corner_radius_top_left = 12
	btn_normal.corner_radius_top_right = 12
	btn_normal.corner_radius_bottom_left = 12
	btn_normal.corner_radius_bottom_right = 12
	btn_normal.content_margin_left = 25
	btn_normal.content_margin_right = 35
	btn_normal.content_margin_top = 15
	btn_normal.content_margin_bottom = 15
	btn_normal.border_width_left = 3
	btn_normal.border_width_top = 3
	btn_normal.border_width_right = 3
	btn_normal.border_width_bottom = 3
	btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.95)
	btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.9)

	btn.add_theme_stylebox_override("normal", btn_normal)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("focus", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_hover)

	btn.reset_size()

	btn.mouse_entered.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.15).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func():
		var t = create_tween()
		t.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)
	)

	btn.pressed.connect(func():
		if SoundManager and SoundManager.has_method("play_sfx"):
			SoundManager.play_sfx("ui_click")
		OS.shell_open("https://patreon.com")
	)

	add_child(btn)

	await get_tree().process_frame
	btn.pivot_offset = btn.size / 2.0
	var screen_size = get_viewport().get_visible_rect().size
	btn.position = Vector2(screen_size.x * 0.5 - (btn.size.x / 2.0), screen_size.y * 0.65 - (btn.size.y / 2.0))
