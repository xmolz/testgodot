# book_reader.gd — autoload "BookReader". shows one spread of a library book: a picture on
# the left page, the text on the right page, large enough to read on phones too. waits
# until the player closes it, so dialogue can call it and carry on afterwards:
#   do BookReader.open("history_of_heredity")
# book data lives in res://data/library_books.gd (BOOKS). per book:
#   title, author, page, heading, body  — right page (body accepts BBCode, e.g. [b]...[/b])
#   image, caption                      — left page. no image: a title plate is shown instead.
extends Node

signal closed

const BOOKS_SCRIPT := preload("res://data/library_books.gd")
const FONT := preload("res://Fonts/VarelaRound-Regular.ttf")
const LAYER := 110                     # above the dialogue balloon
const PAGE_SIZE := Vector2(820, 880)   # each page; the spread is two pages + the gutter
const GUTTER_WIDTH := 10
const PAGE_MARGIN := 44
const TITLE_SIZE := 40
const META_SIZE := 24
const HEADING_SIZE := 34
const BODY_SIZE := 32
const CAPTION_SIZE := 24
const PLATE_TITLE_SIZE := 46
const PAPER := Color(0.96, 0.93, 0.85, 1.0)
const PAPER_EDGE := Color(0.55, 0.47, 0.36, 1.0)
const GUTTER := Color(0.78, 0.72, 0.62, 1.0)
const INK := Color(0.15, 0.13, 0.12, 1.0)
const INK_SOFT := Color(0.38, 0.33, 0.29, 1.0)

var _layer: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func has_book(book_id: String) -> bool:
	return BOOKS_SCRIPT.BOOKS.has(book_id)


func open(book_id: String) -> void:
	if is_instance_valid(_layer):
		return
	if not has_book(book_id):
		push_warning("BookReader: no book '%s' in res://data/library_books.gd" % book_id)
		return
	_build(BOOKS_SCRIPT.BOOKS[book_id])
	await closed


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_layer):
		return
	var wants_close: bool = event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		wants_close = true
	if wants_close:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if not is_instance_valid(_layer):
		return
	_layer.queue_free()
	_layer = null
	closed.emit()


func _build(book: Dictionary) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(center)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	center.add_child(outer)

	# the open book: left page | gutter | right page
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	outer.add_child(spread)

	var left_page := _page(true)
	spread.add_child(left_page)
	var gutter := ColorRect.new()
	gutter.color = GUTTER
	gutter.custom_minimum_size = Vector2(GUTTER_WIDTH, PAGE_SIZE.y)
	spread.add_child(gutter)
	var right_page := _page(false)
	spread.add_child(right_page)

	_fill_picture_page(left_page, book)
	_fill_text_page(right_page, book)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(240, 76)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_override("font", FONT)
	close_button.add_theme_font_size_override("font_size", 32)
	close_button.pressed.connect(_close)
	outer.add_child(close_button)


# one page of paper; the outer corners are rounded, the spine side is square.
func _page(is_left: bool) -> PanelContainer:
	var page := PanelContainer.new()
	page.custom_minimum_size = PAGE_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = PAPER_EDGE
	style.set_border_width_all(4)
	if is_left:
		style.border_width_right = 0
		style.corner_radius_top_left = 12
		style.corner_radius_bottom_left = 12
	else:
		style.border_width_left = 0
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_right = 12
	style.set_content_margin_all(PAGE_MARGIN)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 20
	page.add_theme_stylebox_override("panel", style)
	return page


func _fill_picture_page(page: PanelContainer, book: Dictionary) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	page.add_child(column)
	var image_path: String = str(book.get("image", ""))
	var texture: Texture2D = null
	if image_path != "" and ResourceLoader.exists(image_path):
		texture = load(image_path)
	if texture:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(picture)
		if str(book.get("caption", "")) != "":
			var caption := _label(str(book["caption"]), CAPTION_SIZE, INK_SOFT)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(caption)
	else:
		# no picture yet: a simple title plate, so the page isn't blank
		if image_path != "":
			push_warning("BookReader: image not found: %s" % image_path)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var plate_title := _label(str(book.get("title", "")), PLATE_TITLE_SIZE, INK)
		plate_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(plate_title)
		var rule := ColorRect.new()
		rule.color = INK_SOFT
		rule.custom_minimum_size = Vector2(220, 3)
		rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(rule)
		if str(book.get("author", "")) != "":
			var plate_author := _label(str(book["author"]), META_SIZE + 4, INK_SOFT)
			plate_author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			column.add_child(plate_author)


func _fill_text_page(page: PanelContainer, book: Dictionary) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	page.add_child(column)

	column.add_child(_label(str(book.get("title", "")), TITLE_SIZE, INK))
	var meta_parts: Array = []
	for key in ["author", "page"]:
		if str(book.get(key, "")) != "":
			meta_parts.append(str(book[key]))
	if not meta_parts.is_empty():
		column.add_child(_label(" · ".join(meta_parts), META_SIZE, INK_SOFT))
	if str(book.get("heading", "")) != "":
		column.add_child(_label(str(book["heading"]), HEADING_SIZE, INK))

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.scroll_active = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_override("normal_font", FONT)
	body.add_theme_font_override("bold_font", FONT)
	body.add_theme_font_size_override("normal_font_size", BODY_SIZE)
	body.add_theme_font_size_override("bold_font_size", BODY_SIZE)
	body.add_theme_color_override("default_color", INK)
	body.add_theme_constant_override("line_separation", 6)
	body.text = str(book.get("body", ""))
	column.add_child(body)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
