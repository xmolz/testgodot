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
var _launching: bool = false

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

# TODO: replace with ChapterLaunchSequence (transition shader + dialogue + CG preload pipeline). Keep it minimal — it is a seam, not the final system.
func _launch_chapter(data: MemoryChapterData):
	if _launching:
		return
	_launching = true

	# ***** phase 1: portal transition *****
	await _play_chapter_portal_phase()

	var path = data.scene_path_to_load
	if path.is_empty():
		if NotificationManager:
			NotificationManager.add_notification("This chapter does not have a scene path assigned yet!")
		else:
			print("MemoryBoxOverlay: No scene path assigned for chapter ", data.chapter_name)
		return
		
	# Start threaded background load
	ResourceLoader.load_threaded_request(path)
	
	if is_instance_valid(_active_drawer):
		_active_drawer.close()
		
	# Poll for completion in a process frame loop
	var progress = []
	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var packed_scene = ResourceLoader.load_threaded_get(path)
			if packed_scene:
				get_tree().change_scene_to_packed(packed_scene)
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("MemoryBoxOverlay: Threaded load failed for path: " + path)
			break
		await get_tree().process_frame

# grabs the drawer art, fades the memory box out under it, and hands the art to the
# transition layer to grow and warp. returns once the portal has played out.
func _play_chapter_portal_phase() -> void:
	# grab the art and its screen rect BEFORE close() drops the drawer's reference.
	var portal_texture: Texture2D = null
	var start_rect: Rect2 = Rect2()
	if is_instance_valid(_active_drawer):
		if _active_drawer.has_method("get_detail_texture"):
			portal_texture = _active_drawer.get_detail_texture()
		if _active_drawer.has_method("get_detail_image_global_rect"):
			start_rect = _active_drawer.get_detail_image_global_rect()

	# fade the memory box and the drawer chrome out under the growing art.
	var fade = create_tween().set_parallel(true)
	fade.tween_property(panel, "modulate:a", 0.0, 0.35)
	if is_instance_valid(_active_drawer):
		fade.tween_property(_active_drawer, "modulate:a", 0.0, 0.35)

	if GameManager and is_instance_valid(GameManager.transition_layer) \
			and GameManager.transition_layer.has_method("play_chapter_portal"):
		await GameManager.transition_layer.play_chapter_portal(portal_texture, start_rect)
	else:
		push_warning("MemoryBoxOverlay: transition_layer has no play_chapter_portal(); portal skipped.")

	if is_instance_valid(_active_drawer):
		_active_drawer.close()

	# ***** TEST SLICE ONLY: restore the memory box so the portal can be replayed
	# without restarting the game. delete once the CG phase takes over. *****
	panel.modulate.a = 1.0
	_launching = false
	if NotificationManager:
		NotificationManager.add_notification("Portal complete — chapter launch pipeline not built yet.")

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
