# memoryboxoverlay.gd
extends CanvasLayer

@export var all_memory_data: Array[MemoryGroupData] = []
@export var dev_cta_dialogue: DialogueResource
@onready var location_list_container: VBoxContainer = $Panel/ScrollContainer/LocationListContainer
@onready var back_button: Button = $Panel/BackButton
@onready var panel: Panel = $Panel

const LocationRowScene = preload("res://ui/LocationRow.tscn")
const ADVANCED_OVERLAY_SCENE = preload("res://conversation/AdvancedConversationOverlay.tscn")
const ChapterDetailDrawerScene = preload("res://ui/ChapterDetailDrawer.tscn")

var _active_drawer: Control = null

func _ready():
	back_button.pressed.connect(_on_back_button_pressed)

	# ************ mobile scaling for memory box main ui
	if OS.has_feature("mobile"):
		# perfectly center the title
		var title = $Panel/TitleLabel
		title.add_theme_font_size_override("font_size", 64)
		title.anchor_left = 0.0
		title.anchor_right = 1.0
		title.offset_left = 0
		title.offset_right = 0

		# make the back button much larger
		back_button.add_theme_font_size_override("font_size", 72)
		back_button.custom_minimum_size = Vector2(100, 100)

		# push the chapter list down
		var scroll = $Panel/ScrollContainer
		scroll.anchor_top = 0.20

	_populate_list()

	# hide the panel instantly before
	panel.modulate.a = 0.0

	call_deferred("_restore_patreon_button")

func _populate_list():
	# first, clear any location rows that are already there.
	for child in location_list_container.get_children():
		child.queue_free()

	# show every memory group (category
	for memory_group in all_memory_data:
		var new_row = LocationRowScene.instantiate()
		location_list_container.add_child(new_row)
		new_row.populate(memory_group)
		new_row.chapter_selected.connect(_on_chapter_selected)

# ------------------- signal handlers

func _on_back_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager:
		GameManager.exit_to_world_state()

	print("Back button pressed, closing overlay.")
	DebugVRAM.snapshot("memory box closed")
	queue_free()


func _on_chapter_selected(data: MemoryChapterData):
	if data.triggers_dev_cta:
		if not dev_cta_dialogue:
			push_warning("MemoryBoxOverlay: triggers_dev_cta is set but dev_cta_dialogue is not assigned.")
			return
		# clear the persistent patreon button
		var old_btn = get_node_or_null("PersistentPatreonBtn")
		if is_instance_valid(old_btn):
			old_btn.queue_free()

		var instance = ADVANCED_OVERLAY_SCENE.instantiate()
		instance.dialogue_resource = dev_cta_dialogue
		add_child(instance)
	else:
		if is_instance_valid(_active_drawer):
			return
			
		_active_drawer = ChapterDetailDrawerScene.instantiate()
		_active_drawer.populate(data)
		_active_drawer.begin_pressed.connect(_launch_chapter)
		_active_drawer.drawer_closed.connect(func(): _active_drawer = null)
		add_child.call_deferred(_active_drawer)
		
		# Open when ready in the tree
		_active_drawer.ready.connect(func(): _active_drawer.open())

func _launch_chapter(data: MemoryChapterData):
	ChapterLaunchSequence.launch(data, self, _active_drawer)

# -----------(relaxed retro boot sequence)
func play_boot_sequence():
	# ************[1. setup initial state: transparent, slightly smaller, slightly shifted down]
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.95, 0.95)
	panel.position.y += 20.0
	panel.modulate.a = 0.0
	
	# *****************((future audio spot: a deep, ambient synth hum goes here!))
	# /////////// if soundmanager: soundmanager.play_sfx("ps2_ambient_hum")
	
	# smooth, chill tween
	var tween = create_tween().set_parallel(true)
	
	# phase a: fade in slowly over 1.5 second
	tween.tween_property(panel, "modulate:a", 1.0, 1.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# phase b: gently float up
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
