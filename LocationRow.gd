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
var _target_scroll_x: float = 0.0 
var _is_scrolling: bool = false   
var memory_data: MemoryGroupData

func _ready():
	left_arrow_button.pressed.connect(_on_left_arrow_pressed)
	right_arrow_button.pressed.connect(_on_right_arrow_pressed)

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
	# Wait two frames to guarantee deeply nested UI panels have settled their layout
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_panel = $ChaptersAreaPanel/HBoxContainer/ViewportPanel
	var viewport_width = viewport_panel.size.x
	
	# FIX: Use get_combined_minimum_size() to get the true mathematical width instantly!
	var content_width = chapter_list_container.get_combined_minimum_size().x

	var max_scroll = max(0.0, content_width - viewport_width)

	left_arrow_button.disabled = (_target_scroll_x >= -1.0)
	right_arrow_button.disabled = (_target_scroll_x <= -max_scroll + 1.0)

func _on_left_arrow_pressed():
	if _is_scrolling or left_arrow_button.disabled: return

	var viewport_width = $ChaptersAreaPanel/HBoxContainer/ViewportPanel.size.x
	_target_scroll_x = min(0.0, _target_scroll_x + viewport_width)
	_animate_scroll()

func _on_chapter_button_selected(data: MemoryChapterData):
	emit_signal("chapter_selected", data)

func _on_right_arrow_pressed():
	if _is_scrolling or right_arrow_button.disabled: return

	var viewport_width = $ChaptersAreaPanel/HBoxContainer/ViewportPanel.size.x
	
	# FIX: Also update this here so it calculates perfectly while scrolling
	var content_width = chapter_list_container.get_combined_minimum_size().x

	var max_scroll = max(0.0, content_width - viewport_width)

	_target_scroll_x = max(-max_scroll, _target_scroll_x - viewport_width)
	_animate_scroll()

func _animate_scroll():
	_is_scrolling = true

	var tween = create_tween()
	tween.tween_property(chapter_list_container, "position:x", _target_scroll_x, scroll_speed)\
		 .set_trans(Tween.TRANS_SINE)\
		 .set_ease(Tween.EASE_OUT)

	await tween.finished
	_is_scrolling = false
	_update_arrow_state()
