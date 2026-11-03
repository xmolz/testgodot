# locationrow.gd
extends HBoxContainer
signal chapter_selected(data: MemoryChapterData)

@onready var location_name_label: Label = $LocationInfoPanel/VBoxContainer/Label
@onready var location_image_rect: TextureRect = $LocationInfoPanel/VBoxContainer/TextureRect
@onready var chapter_list_container: HBoxContainer = $ChaptersAreaPanel/HBoxContainer/ViewportPanel/ChapterListContainer
@onready var left_arrow_button: Button = $ChaptersAreaPanel/HBoxContainer/LeftArrowButton
@onready var right_arrow_button: Button = $ChaptersAreaPanel/HBoxContainer/RightArrowButton

const ChapterButtonScene = preload("res://ui/ChapterButton.tscn") 
const ChapterButtonScript = preload("res://ui/ChapterButton.gd")   # step 2.429: its static lock check
# step 2.431 / 2.435: the size of every location picture on mobile; the info panel is as wide as this plus its
# margins. PC uses the scene's own sizes.
const LOCATION_IMAGE_SIZE_MOBILE := Vector2(165, 118)

@export var scroll_speed: float = 0.5
var memory_data: MemoryGroupData

func _ready():
	left_arrow_button.pressed.connect(_on_left_arrow_pressed)
	right_arrow_button.pressed.connect(_on_right_arrow_pressed)

	# connect the native scrollbar so
	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	viewport_panel.get_h_scroll_bar().value_changed.connect(func(_val): _update_arrow_state())

	# ///////////// touch scroll fix
	# ensure the container itself doesn't block touch input
	viewport_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	chapter_list_container.mouse_filter = Control.MOUSE_FILTER_PASS

	# ----------------------- mobile scaling for location row
	if OS.has_feature("mobile"):
		# scaled to ~70% for mobile
		$LocationInfoPanel.custom_minimum_size = Vector2(205, 190)
		location_name_label.add_theme_font_size_override("font_size", 24)

		left_arrow_button.add_theme_font_size_override("font_size", 48)
		left_arrow_button.custom_minimum_size.x = 72

		right_arrow_button.add_theme_font_size_override("font_size", 48)
		right_arrow_button.custom_minimum_size.x = 72

		# tighten the gap between chapter
		chapter_list_container.add_theme_constant_override("separation", 34)

func populate(data: MemoryGroupData):
	self.memory_data = data

	# step 2.308: a location that isn't open yet shows "?" for its name and picture, and locks all its chapters
	var location_locked: bool = is_location_locked()
	if location_locked:
		# step 2.309: one "?" on the picture is enough; the name stays blank (a space keeps its height)
		location_name_label.text = " "
		_show_unknown_tile()
	else:
		location_name_label.text = memory_data.group_name
		if not memory_data.group_thumbnail_path.is_empty() and ResourceLoader.exists(memory_data.group_thumbnail_path):
			location_image_rect.texture = load(memory_data.group_thumbnail_path)
	# step 2.430 / 2.431 / 2.435: on mobile only, every location picture is the same box (width and height);
	# the art fills it, keeping its aspect, cropped, and the name wraps inside the panel instead of widening
	# it. PC keeps the sizes the scene defines.
	if OS.has_feature("mobile"):
		location_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		location_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		location_image_rect.custom_minimum_size = LOCATION_IMAGE_SIZE_MOBILE
		location_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		location_name_label.custom_minimum_size.x = 0
		location_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		$LocationInfoPanel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	# step 2.430: a locked row has nothing to scroll to: no touch drag, arrows off
	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	if viewport_panel is ScrollContainer:
		# step 2.431: "show never" scrolls by drag and arrows without drawing a bar.
		# step 2.432: never "disabled": that makes the container as wide as its content and the row overflows
		# the box. a locked row stops the touch drag by ignoring input instead.
		viewport_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		viewport_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if location_locked else Control.MOUSE_FILTER_PASS
	if location_locked:
		left_arrow_button.disabled = true
		right_arrow_button.disabled = true

	for child in chapter_list_container.get_children():
		child.queue_free()

	for chapter_data in memory_data.chapters:
		# step 2.429: a chapter that is hidden while locked isn't a tile at all
		if chapter_data == null or chapter_is_hidden(chapter_data):
			continue
		var new_chapter_button = ChapterButtonScene.instantiate()
		chapter_list_container.add_child(new_chapter_button)
		new_chapter_button.populate(chapter_data, location_locked)
		new_chapter_button.chapter_selected.connect(_on_chapter_button_selected)

	_update_arrow_state()

## step 2.308: true while this location's unlock_flag is still false (the "unlock all chapters" dev toggle
## on Main opens every location too)
func is_location_locked() -> bool:
	if memory_data == null or memory_data.unlock_flag.is_empty():
		return false
	# step 2.324: the dev "unlock all" only opens a location that has at least one playable chapter
	if Engine.get_meta("dev_unlock_all_chapters", false):
		for chapter in memory_data.chapters:
			if chapter and _chapter_playable(chapter):
				return false
	return not Flags.get_game_flag(memory_data.unlock_flag)

func _chapter_playable(chapter: MemoryChapterData) -> bool:
	return not chapter.scene_path_to_load.strip_edges().is_empty() or not chapter.intro_overlay_path.strip_edges().is_empty()


## step 2.429: a chapter marked hidden_until_unlocked, while its flag is still false (the dev "unlock all" counts
## as unlocked for playable chapters, as everywhere else)
static func chapter_is_hidden(chapter: MemoryChapterData) -> bool:
	if chapter == null or not chapter.hidden_until_unlocked:
		return false
	return ChapterButtonScript.is_chapter_locked(chapter)


## step 2.429: does this location get a row at all? a location marked hidden_until_a_chapter_opens needs one
## chapter that is shown and unlocked (and its own unlock_flag, if any, must already be true).
static func group_shows(data: MemoryGroupData) -> bool:
	if data == null:
		return false
	if not data.hidden_until_a_chapter_opens:
		return true
	if not data.unlock_flag.is_empty() and not Flags.get_game_flag(data.unlock_flag) \
			and not Engine.get_meta("dev_unlock_all_chapters", false):
		return false
	for chapter in data.chapters:
		if chapter == null or chapter_is_hidden(chapter):
			continue
		if not ChapterButtonScript.is_chapter_locked(chapter):
			return true
	return false

## step 2.308: the first chapter in this row that is newly unlocked (glowing), or null
func get_new_chapter_button() -> Control:
	for b in chapter_list_container.get_children():
		if not b.is_queued_for_deletion() and "is_new" in b and b.is_new:
			return b
	return null

## step 2.308: scroll this row sideways so the given chapter button is in view
func scroll_to_chapter(button: Control) -> void:
	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	if viewport_panel is ScrollContainer and is_instance_valid(button):
		viewport_panel.ensure_control_visible(button)

func _show_unknown_tile() -> void:
	location_image_rect.texture = null
	var bg := ColorRect.new()
	bg.color = Color(0.085, 0.092, 0.14)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	location_image_rect.add_child(bg)
	var q := Label.new()
	q.text = "?"
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.set_anchors_preset(Control.PRESET_FULL_RECT)
	q.add_theme_color_override("font_color", Color(0.537, 0.867, 1.0, 0.55))
	q.add_theme_font_size_override("font_size", 96 if OS.has_feature("mobile") else 72)
	location_image_rect.add_child(q)

func _update_arrow_state():
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	var viewport_width = viewport_panel.size.x
	var content_width = chapter_list_container.get_combined_minimum_size().x
	var max_scroll = max(0.0, content_width - viewport_width)

	# step 2.430: a locked row keeps both arrows off
	if is_location_locked():
		left_arrow_button.disabled = true
		right_arrow_button.disabled = true
		return
	left_arrow_button.disabled = (viewport_panel.scroll_horizontal <= 0)
	right_arrow_button.disabled = (viewport_panel.scroll_horizontal >= max_scroll)

func _on_left_arrow_pressed():
	if left_arrow_button.disabled: return
	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	var target = max(0.0, viewport_panel.scroll_horizontal - viewport_panel.size.x)
	create_tween().tween_property(viewport_panel, "scroll_horizontal", target, scroll_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_chapter_button_selected(data: MemoryChapterData):
	emit_signal("chapter_selected", data)

func _on_right_arrow_pressed():
	if right_arrow_button.disabled: return
	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	var content_width = chapter_list_container.get_combined_minimum_size().x
	var max_scroll = max(0.0, content_width - viewport_panel.size.x)
	var target = min(max_scroll, viewport_panel.scroll_horizontal + viewport_panel.size.x)
	create_tween().tween_property(viewport_panel, "scroll_horizontal", target, scroll_speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _exit_tree():
	location_image_rect.texture = null
