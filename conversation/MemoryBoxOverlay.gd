# memoryboxoverlay.gd
extends CanvasLayer

@export var all_memory_data: Array[MemoryGroupData] = []
@export var dev_cta_dialogue: DialogueResource
@onready var location_list_container: VBoxContainer = $Panel/ScrollContainer/LocationListContainer
@onready var back_button: Button = $Panel/BackButton
@onready var panel: Panel = $Panel

const LocationRowScene = preload("res://ui/LocationRow.tscn")
const LocationRowScript = preload("res://ui/LocationRow.gd")   # step 2.429: its static row rule
const ADVANCED_OVERLAY_SCENE = preload("res://conversation/AdvancedConversationOverlay.tscn")
const ChapterDetailDrawerScene = preload("res://ui/ChapterDetailDrawer.tscn")
# step 2.421: the one-time "this is where this build ends" note (see _show_build_end_note_once)
const BUILD_END_NOTE_FLAG := "build_end_note_seen"
const BUILD_END_NOTE_TITLE := "build_end_note"
const BUILD_END_NOTE_DIALOGUE_PATH := "res://dialogue/chapter_launch.dialogue"
const BUILD_END_NOTE_BALLOON_PATH := "res://conversation/conversationballoon.tscn"
# step 2.315: one knob for the size of all text in the memory box and its drawer (PC)
const UITextScale = preload("res://ui/UITextScale.gd")

var _active_drawer: Control = null

func _ready():
	back_button.pressed.connect(_on_back_button_pressed)

	# forces shader pipeline compilation while the memory box is booting
	_pre_warm_shader()

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

	# step 2.309: the same chunky cyan scrollbar as the settings menu and the controls screen.
	# step 2.311: done BEFORE the rows exist. it moves the list into a margin container, and moving rows
	# that are already filled out of the tree runs their _exit_tree(), which drops their pictures (the
	# VRAM release) - that's what blanked the chapter and location pictures in step 2.310.
	_style_scrollbar()
	_populate_list()
	# step 2.315: bigger text on PC (the title keeps its size)
	UITextScale.apply(panel, UITextScale.memory_box_factor(), [$Panel/TitleLabel])
	# step 2.308: bring a newly unlocked chapter into view
	_focus_new_chapter()

	# hide the panel instantly before
	panel.modulate.a = 0.0

	call_deferred("_restore_patreon_button")

func _populate_list():
	# first, clear any location rows that are already there.
	for child in location_list_container.get_children():
		child.queue_free()

	# show every memory group (category
	for memory_group in all_memory_data:
		# step 2.429: a location with nothing to show yet gets no row
		if not LocationRowScript.group_shows(memory_group):
			continue
		var new_row = LocationRowScene.instantiate()
		location_list_container.add_child(new_row)
		new_row.populate(memory_group)
		new_row.chapter_selected.connect(_on_chapter_selected)

# ------------------- signal handlers

func _on_back_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	if GameManager:
		GameManager.exit_to_world_state()
	if SoundManager and SoundManager.has_method("resume_ambience"):
		SoundManager.resume_ambience(1.0)

	print("Back button pressed, closing overlay.")
	DebugVRAM.snapshot("memory box closed")
	# step 2.421: once, after Keeping Busy is finished: the end-of-build note
	_show_build_end_note_once()
	queue_free()


# step 2.421: the first time the box is closed with chapter_keeping_busy_done set, a speaker-less balloon from
# chapter_launch.dialogue (~ build_end_note). the Think verb's path: hold the player, show the balloon, and
# GameManager.restore_world_after_object_dialogue hands control back when it ends.
func _show_build_end_note_once() -> void:
	if not Flags.get_game_flag("chapter_keeping_busy_done") or Flags.get_game_flag(BUILD_END_NOTE_FLAG):
		return
	if ChapterLaunchSequence and ChapterLaunchSequence.is_launching():
		return
	if not ResourceLoader.exists(BUILD_END_NOTE_DIALOGUE_PATH):
		return
	var note_resource = load(BUILD_END_NOTE_DIALOGUE_PATH)
	var table = note_resource.get("titles") if note_resource else null
	if table == null and note_resource:
		table = note_resource.get("cues")
	if not (table is Dictionary) or not table.has(BUILD_END_NOTE_TITLE):
		push_warning("MemoryBoxOverlay: '%s' is missing from chapter_launch.dialogue." % BUILD_END_NOTE_TITLE)
		return
	Flags.set_game_flag(BUILD_END_NOTE_FLAG, true)
	if GameManager:
		if is_instance_valid(GameManager.player_node) and GameManager.player_node.has_method("set_can_move"):
			GameManager.player_node.set_can_move(false)
		if not DialogueManager.dialogue_ended.is_connected(GameManager.restore_world_after_object_dialogue):
			DialogueManager.dialogue_ended.connect(GameManager.restore_world_after_object_dialogue, CONNECT_ONE_SHOT)
	DialogueManager.show_dialogue_balloon_scene(BUILD_END_NOTE_BALLOON_PATH, note_resource, BUILD_END_NOTE_TITLE)


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
	# step 2.308: the memory box test on Main skips the chapter itself: a quick portal, and it counts as finished
	if Engine.get_meta("dev_quick_chapters", false):
		ChapterLaunchSequence.quick_complete(data, self, _active_drawer)
		return
	ChapterLaunchSequence.launch(data, self, _active_drawer)

## step 2.309: the list's scrollbar in the settings menu's style (a dark track and a cyan grabber).
## step 2.310: wider than the settings one (20 px on PC, 36 px on mobile), with a gap between it and the
## rows' right arrows: the list is moved into a MarginContainer with a right margin, as settings does.
func _style_scrollbar() -> void:
	var scroll = get_node_or_null("Panel/ScrollContainer")
	if not scroll is ScrollContainer:
		return
	var is_mobile: bool = OS.has_feature("mobile")

	if location_list_container.get_parent() == scroll:
		var margin := MarginContainer.new()
		margin.name = "ScrollMargin"
		margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin.add_theme_constant_override("margin_right", 40 if is_mobile else 24)
		scroll.remove_child(location_list_container)
		margin.add_child(location_list_container)
		scroll.add_child(margin)
		location_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# step 2.431: the list only ever scrolls up and down; sideways scrolling belongs to the rows
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vbar: VScrollBar = scroll.get_v_scroll_bar()
	vbar.custom_minimum_size.x = 36 if is_mobile else 20

	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.1, 0.12, 0.15, 1.0)
	track_style.set_corner_radius_all(8)

	var grabber_style := StyleBoxFlat.new()
	grabber_style.bg_color = Color(0.2, 0.85, 1.0, 0.9)
	grabber_style.set_corner_radius_all(8)

	var grabber_hl: StyleBoxFlat = grabber_style.duplicate()
	grabber_hl.bg_color = Color(0.2, 0.85, 1.0, 1.0)

	vbar.add_theme_stylebox_override("scroll", track_style)
	vbar.add_theme_stylebox_override("scroll_focus", track_style)
	vbar.add_theme_stylebox_override("grabber", grabber_style)
	vbar.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	vbar.add_theme_stylebox_override("grabber_pressed", grabber_hl)

	if is_mobile:
		scroll.scroll_deadzone = 24

## step 2.308: rebuild the rows (after a chapter is finished in place) and bring any new chapter into view.
func refresh() -> void:
	_populate_list()
	UITextScale.apply(panel, UITextScale.memory_box_factor(), [$Panel/TitleLabel])
	_focus_new_chapter()

## step 2.308: scroll the list to the first row with a newly unlocked chapter, and that row to the chapter.
func _focus_new_chapter() -> void:
	# rows and buttons need a couple of frames to be laid out before scrolling means anything
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll = get_node_or_null("Panel/ScrollContainer")
	for row in location_list_container.get_children():
		if row.is_queued_for_deletion() or not row.has_method("get_new_chapter_button"):
			continue
		var button = row.get_new_chapter_button()
		if button:
			if scroll is ScrollContainer:
				scroll.ensure_control_visible(row)
			row.scroll_to_chapter(button)
			return

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

func _pre_warm_shader() -> void:
	var warm_rect = TextureRect.new()
	warm_rect.name = "PortalPreWarm"
	warm_rect.texture = PlaceholderTexture2D.new()
	warm_rect.texture.set_size(Vector2(2, 2))
	var warm_mat = ShaderMaterial.new()
	warm_mat.shader = preload("res://ui/chapter_portal.gdshader")
	warm_rect.material = warm_mat
	warm_rect.modulate.a = 0.0
	add_child(warm_rect)
	# await two process frames to force draw compile
	await get_tree().process_frame
	await get_tree().process_frame
	warm_rect.material = null
	warm_rect.queue_free()
	warm_mat = null
