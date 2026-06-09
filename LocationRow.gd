# LocationRow.gd
extends HBoxContainer
signal chapter_selected(data: MemoryChapterData)

@onready var location_name_label: Label = $LocationInfoPanel/VBoxContainer/Label
@onready var location_image_rect: TextureRect = $LocationInfoPanel/VBoxContainer/TextureRect
@onready var chapter_list_container: HBoxContainer = $ChaptersAreaPanel/HBoxContainer/ViewportPanel/ChapterListContainer
@onready var left_arrow_button: Button = $ChaptersAreaPanel/HBoxContainer/LeftArrowButton
@onready var right_arrow_button: Button = $ChaptersAreaPanel/HBoxContainer/RightArrowButton

const ChapterButtonScene = preload("res://ChapterButton.tscn") 

@export var scroll_speed: float = 0.5
var memory_data: MemoryGroupData

func _ready():
	left_arrow_button.pressed.connect(_on_left_arrow_pressed)
	right_arrow_button.pressed.connect(_on_right_arrow_pressed)

	# Connect the native scrollbar so arrows update dynamically when the user swipes
	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	viewport_panel.get_h_scroll_bar().value_changed.connect(func(_val): _update_arrow_state())

	# --- TOUCH SCROLL FIX ---
	# Ensure the container itself doesn't block touch input
	viewport_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	chapter_list_container.mouse_filter = Control.MOUSE_FILTER_PASS

	# --- MOBILE SCALING FOR LOCATION ROW ---
	if OS.has_feature("mobile"):
		# Increase Y from 200 to 280 to allow the chapter buttons to fit without squishing
		$LocationInfoPanel.custom_minimum_size = Vector2(300, 280)
		location_name_label.add_theme_font_size_override("font_size", 32)

		left_arrow_button.add_theme_font_size_override("font_size", 64)
		left_arrow_button.custom_minimum_size.x = 90

		right_arrow_button.add_theme_font_size_override("font_size", 64)
		right_arrow_button.custom_minimum_size.x = 90

func populate(data: MemoryGroupData):
	self.memory_data = data

	location_name_label.text = memory_data.group_name
	location_image_rect.texture = memory_data.group_image

	for child in chapter_list_container.get_children():
		child.queue_free()

	for chapter_data in memory_data.chapters:
		var new_chapter_button = ChapterButtonScene.instantiate()
		chapter_list_container.add_child(new_chapter_button)
		new_chapter_button.populate(chapter_data)
		new_chapter_button.chapter_selected.connect(_on_chapter_button_selected)

	_update_arrow_state()

func _update_arrow_state():
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	var viewport_width = viewport_panel.size.x
	var content_width = chapter_list_container.get_combined_minimum_size().x
	var max_scroll = max(0.0, content_width - viewport_width)

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
