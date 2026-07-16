# MemoryBoxOverlay.gd
extends CanvasLayer

@export var all_memory_data: Array[MemoryGroupData] = []
@export var dev_cta_dialogue: DialogueResource
@onready var location_list_container: VBoxContainer = $Panel/ScrollContainer/LocationListContainer
@onready var back_button: Button = $Panel/BackButton
@onready var panel: Panel = $Panel

const LocationRowScene = preload("res://ui/LocationRow.tscn")
const ADVANCED_OVERLAY_SCENE = preload("res://conversation/AdvancedConversationOverlay.tscn")

func _ready():
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

		# Push the chapter list down to create a gap below the main title
		var scroll = $Panel/ScrollContainer
		scroll.anchor_top = 0.20

	_populate_list()

	# Hide the panel instantly before the screen even becomes visible
	panel.modulate.a = 0.0

	call_deferred("_restore_patreon_button")

func _populate_list():
	# First, clear any location rows that are already there.
	for child in location_list_container.get_children():
		child.queue_free()

	# Show every memory group (category filtering removed with the Story/Spicy toggle).
	for memory_group in all_memory_data:
		var new_row = LocationRowScene.instantiate()
		location_list_container.add_child(new_row)
		new_row.populate(memory_group)
		new_row.chapter_selected.connect(_on_chapter_selected)

# --- Signal Handlers ---

func _on_back_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager:
		GameManager.exit_to_world_state()

	print("Back button pressed, closing overlay.")
	queue_free()


func _on_chapter_selected(data: MemoryChapterData):
	if data.triggers_dev_cta:
		if not dev_cta_dialogue:
			push_warning("MemoryBoxOverlay: triggers_dev_cta is set but dev_cta_dialogue is not assigned.")
			return
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
	if not Flags.get_level_flag("dev_cta_completed"):
		return
	var existing = get_node_or_null("PersistentPatreonBtn")
	if is_instance_valid(existing):
		return

	var tex = load("res://Icons/patreon_logo.png")
	if not tex:
		return

	var custom_font = load("res://Fonts/VarelaRound-Regular.ttf")

	var btn = Button.new()
	btn.name = "PersistentPatreonBtn"
	btn.text = " Support on Patreon"
	btn.icon = tex
	btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 96)
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
		OS.shell_open(PatreonWorldButton.PATREON_URL)
	)

	add_child(btn)

	await get_tree().process_frame
	btn.pivot_offset = btn.size / 2.0
	var screen_size = get_viewport().get_visible_rect().size
	btn.position = Vector2(screen_size.x * 0.5 - (btn.size.x / 2.0), screen_size.y * 0.65 - (btn.size.y / 2.0))
