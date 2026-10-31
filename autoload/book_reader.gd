# book_reader.gd - autoload "BookReader". shows a library book as an open spread: a picture on
# the left page, the text on the right page, large enough to read on phones too. waits
# until the player closes it, so dialogue can call it and carry on afterwards:
#   do BookReader.open("history_of_heredity")
# book data lives in res://data/library_books.gd (BOOKS). per book:
#   title, author, page, heading, body  - right page (body accepts BBCode, e.g. [b]...[/b])
#   pages                               - optional Array of body texts, one per page, used instead
#                                         of body. back / forward arrows (or left / right keys) turn
#                                         them, and the meta line shows "Page N of M" in place of page.
#   image, caption                      - left page. no image: a title plate is shown instead.
#   page_flags                          - optional {page index: level flag name}: set when that page is shown.
# pages never scroll: text that would run off the bottom steps its font size down until it fits.
extends Node

signal closed

const BOOKS_SCRIPT := preload("res://data/library_books.gd")
const FONT := preload("res://Fonts/VarelaRound-Regular.ttf")
const ARROW := preload("res://Icons/up_arrow.png")
const LAYER := 110                     # above the dialogue balloon
const PAGE_SIZE := Vector2(820, 880)   # each page; the spread is two pages + the gutter
const GUTTER_WIDTH := 10
const PAGE_MARGIN := 44
const TITLE_SIZE := 40
const META_SIZE := 24
const HEADING_SIZE := 34
const BODY_SIZE := 32
const MIN_BODY_SIZE := 22              # shrink-to-fit never goes below this
const CAPTION_SIZE := 24
const PLATE_TITLE_SIZE := 46
const BUTTON_HEIGHT := 76
const ARROW_BUTTON_WIDTH := 120
const ARROW_ICON_SIZE := 40
const ARROW_DISABLED_ALPHA := 0.25
const PAPER := Color(0.96, 0.93, 0.85, 1.0)
const PAPER_EDGE := Color(0.55, 0.47, 0.36, 1.0)
const GUTTER := Color(0.78, 0.72, 0.62, 1.0)
const INK := Color(0.15, 0.13, 0.12, 1.0)
const INK_SOFT := Color(0.38, 0.33, 0.29, 1.0)

var _layer: CanvasLayer = null
var _book: Dictionary = {}
var _pages: Array = []
var _page_index := 0
var _meta_label: Label = null
var _body: RichTextLabel = null
var _back_button: Button = null
var _forward_button: Button = null
var _fit_token := 0                    # bumped on every page change, so a stale fit stops


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
		return
	if _pages.size() > 1:
		if event.is_action_pressed("ui_left"):
			get_viewport().set_input_as_handled()
			_turn(-1)
		elif event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
			_turn(1)


func _close() -> void:
	if not is_instance_valid(_layer):
		return
	_fit_token += 1
	_layer.queue_free()
	_layer = null
	_book = {}
	_pages = []
	_meta_label = null
	_body = null
	_back_button = null
	_forward_button = null
	closed.emit()


func _build(book: Dictionary) -> void:
	_book = book
	_pages = _pages_of(book)
	_page_index = 0

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

	# button row: [back]  Close  [forward]. the arrows only exist for books with several pages.
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	outer.add_child(buttons)

	if _pages.size() > 1:
		_back_button = _arrow_button(true)
		_back_button.pressed.connect(_turn.bind(-1))
		buttons.add_child(_back_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(240, BUTTON_HEIGHT)
	close_button.add_theme_font_override("font", FONT)
	close_button.add_theme_font_size_override("font_size", 32)
	close_button.pressed.connect(_close)
	buttons.add_child(close_button)

	if _pages.size() > 1:
		_forward_button = _arrow_button(false)
		_forward_button.pressed.connect(_turn.bind(1))
		buttons.add_child(_forward_button)

	_show_page(0)


# the body texts to page through: "pages" when the book has it, otherwise the single "body".
func _pages_of(book: Dictionary) -> Array:
	var pages: Array = []
	if book.get("pages") is Array:
		for text in book["pages"]:
			pages.append(str(text))
	if pages.is_empty():
		pages.append(str(book.get("body", "")))
	return pages


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
	_meta_label = _label("", META_SIZE, INK_SOFT)
	column.add_child(_meta_label)
	if str(book.get("heading", "")) != "":
		column.add_child(_label(str(book["heading"]), HEADING_SIZE, INK))

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.scroll_active = false
	_body.clip_contents = true
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_theme_font_override("normal_font", FONT)
	_body.add_theme_font_override("bold_font", FONT)
	_body.add_theme_color_override("default_color", INK)
	_body.add_theme_constant_override("line_separation", 6)
	_set_body_size(BODY_SIZE)
	column.add_child(_body)


func _meta_text() -> String:
	var parts: Array = []
	if str(_book.get("author", "")) != "":
		parts.append(str(_book["author"]))
	if _pages.size() > 1:
		parts.append("Page %d of %d" % [_page_index + 1, _pages.size()])
	elif str(_book.get("page", "")) != "":
		parts.append(str(_book["page"]))
	return " · ".join(parts)


func _show_page(index: int) -> void:
	if not is_instance_valid(_body):
		return
	_page_index = clampi(index, 0, _pages.size() - 1)
	# step 2.268: a page can mark that it was seen (e.g. the clue book's letter-date page).
	var page_flags = _book.get("page_flags", {})
	if page_flags is Dictionary and page_flags.has(_page_index):
		Flags.set_level_flag(str(page_flags[_page_index]), true)
	_meta_label.text = _meta_text()
	_meta_label.visible = _meta_label.text != ""
	_body.text = _pages[_page_index]
	_set_body_size(BODY_SIZE)
	_body.modulate.a = 0.0
	_fit_token += 1
	_fit_body(_fit_token)
	_style_arrow(_back_button, _page_index == 0)
	_style_arrow(_forward_button, _page_index >= _pages.size() - 1)


func _turn(step: int) -> void:
	var target := clampi(_page_index + step, 0, _pages.size() - 1)
	if target == _page_index:
		return
	if SoundManager:
		SoundManager.play_sfx("ui_click")
	_show_page(target)


# a page keeps its full text size unless it would run off the bottom; then it steps down until it
# fits. hidden while it measures so the player never sees it resize.
func _fit_body(token: int) -> void:
	await get_tree().process_frame
	var font_size := BODY_SIZE
	while token == _fit_token and is_instance_valid(_body) and font_size > MIN_BODY_SIZE and _body.get_content_height() > _body.size.y:
		font_size -= 2
		_set_body_size(font_size)
		await get_tree().process_frame
	if token == _fit_token and is_instance_valid(_body):
		_body.modulate.a = 1.0


func _set_body_size(font_size: int) -> void:
	_body.add_theme_font_size_override("normal_font_size", font_size)
	_body.add_theme_font_size_override("bold_font_size", font_size)


# a page arrow like the journal's: up_arrow.png turned to point back or forward, drawn white
# through a clipped ColorRect. the icon and tint ignore the mouse so the whole button is clickable.
func _arrow_button(is_back: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(ARROW_BUTTON_WIDTH, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	var icon := TextureRect.new()
	icon.name = "IconRect"
	icon.texture = ARROW
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var half := ARROW_ICON_SIZE / 2.0
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -half
	icon.offset_top = -half
	icon.offset_right = half
	icon.offset_bottom = half
	icon.pivot_offset = Vector2(half, half)
	icon.rotation = deg_to_rad(-90.0 if is_back else 90.0)
	button.add_child(icon)
	var tint := ColorRect.new()
	tint.color = Color.WHITE
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.add_child(tint)
	return button


# a disabled arrow dims its icon and drops the hand cursor so it reads as unavailable.
func _style_arrow(button: Button, disabled: bool) -> void:
	if not is_instance_valid(button):
		return
	button.disabled = disabled
	var icon := button.get_node_or_null("IconRect") as CanvasItem
	if icon:
		icon.modulate = Color(1, 1, 1, ARROW_DISABLED_ALPHA) if disabled else Color.WHITE
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if disabled else Control.CURSOR_POINTING_HAND


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
