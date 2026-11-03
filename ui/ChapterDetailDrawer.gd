# chapterdetaildrawer.gd
extends Control

signal begin_pressed(data: MemoryChapterData)
signal drawer_closed

# how much of the viewport width the desktop drawer covers, and the pixel width
# it is never allowed to exceed (keeps it sane on ultrawide and 4k displays).
const DESKTOP_DRAWER_WIDTH_RATIO: float = 0.60
const DESKTOP_DRAWER_MAX_WIDTH: float = 1600.0
# the detail image is sized to the source art's own aspect ratio, then clamped
# into this band so it is never a thin strip and never eats the whole drawer.
const DETAIL_IMAGE_MIN_RATIO_DESKTOP: float = 0.40
const DETAIL_IMAGE_MAX_RATIO_DESKTOP: float = 0.60
const DETAIL_IMAGE_MIN_RATIO_MOBILE: float = 0.35
const DETAIL_IMAGE_MAX_RATIO_MOBILE: float = 0.55
# the image never shrinks below this, whatever the window size.
const DETAIL_IMAGE_MIN_HEIGHT: float = 140.0
# horizontal space the drawer's margins and left border take from the image.
const DRAWER_CONTENT_H_PADDING: float = 53.0
# vertical space kept free for title, badge, description and begin button.
const CONTENT_RESERVE_DESKTOP: float = 260.0
const CONTENT_RESERVE_MOBILE: float = 340.0

@onready var dim_rect: ColorRect = $DimRect
@onready var drawer_panel: PanelContainer = $DrawerPanel
@onready var detail_image: TextureRect = $DrawerPanel/Margin/VBox/DetailImage
@onready var title_label: Label = $DrawerPanel/Margin/VBox/TitleRow/TitleLabel
@onready var optional_badge: PanelContainer = $DrawerPanel/Margin/VBox/TitleRow/OptionalBadge
@onready var optional_label: Label = $DrawerPanel/Margin/VBox/TitleRow/OptionalBadge/OptionalLabel
@onready var type_badge: PanelContainer = $DrawerPanel/Margin/VBox/TypeBadge
@onready var badge_label: Label = $DrawerPanel/Margin/VBox/TypeBadge/BadgeLabel
@onready var description_label: Label = $DrawerPanel/Margin/VBox/Scroll/ScrollVBox/DescriptionLabel
@onready var tags_container: HFlowContainer = $DrawerPanel/Margin/VBox/Scroll/ScrollVBox/TagsContainer
@onready var begin_button: Button = $DrawerPanel/Margin/VBox/BeginButton

var chapter_data: MemoryChapterData
var loaded_texture: Texture2D = null
var _tween: Tween
var _is_closing: bool = false
# step 2.419: a finished chapter offers a replay, with a line saying it changes nothing
const REPLAY_BUTTON_TEXT := "Replay"
const REPLAY_NOTE_TEXT := "You've already relived this one. Playing it again won't change what happened, or what comes after."
var _begin_text_default: String = ""
var _replay_note: Label = null
var _button_row: HBoxContainer = null   # step 2.430: Back + Begin on mobile; null on desktop
var _is_mobile: bool = false

# step 2.314: what each info row means, shown in a small callout when its label is clicked or tapped
const INFO_TEXT := {
	"Insurance form": "This memory holds clues to these fields on your insurance form. \"(partial)\" means you'll only find part of the answer here.",
	"Content": "Adult content in this chapter that can't be skipped.",
	"Skippable": "Adult content you can choose to avoid. You'll get the choice when it comes up.",
}
const CALLOUT_CYAN := Color(0.537255, 0.866667, 1.0)
# step 2.315: the same text-size knob as the memory box
const UITextScale = preload("res://ui/UITextScale.gd")
var _callout: PanelContainer = null
var _callout_owner: Control = null
var _scroll_hooked: bool = false

func _ready():
	_is_mobile = OS.has_feature("mobile")
	dim_rect.gui_input.connect(_on_dim_rect_gui_input)
	begin_button.pressed.connect(_on_begin_pressed)
	
	# Initial anim setup
	dim_rect.color.a = 0.0
	
	if _is_mobile:
		_setup_mobile_layout()
	else:
		_setup_desktop_layout()

	# step 2.316: the title (with its badges) sits over the bottom of the image, and the image crops to fit
	_setup_image_overlay()
		
	_update_detail_image_height()
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_update_detail_image_height):
		vp.size_changed.connect(_update_detail_image_height)

	if chapter_data != null:
		_apply_data()

func _desktop_drawer_ratio() -> float:
	# 60% of the viewport, but never wider than DESKTOP_DRAWER_MAX_WIDTH pixels.
	var vp_w: float = get_viewport_rect().size.x
	if vp_w <= 0.0:
		return DESKTOP_DRAWER_WIDTH_RATIO
	return minf(DESKTOP_DRAWER_WIDTH_RATIO, DESKTOP_DRAWER_MAX_WIDTH / vp_w)

func _setup_desktop_layout():
	drawer_panel.anchors_preset = Control.PRESET_RIGHT_WIDE
	drawer_panel.anchor_left = 1.0 - _desktop_drawer_ratio()
	drawer_panel.anchor_right = 1.0
	drawer_panel.anchor_top = 0.0
	drawer_panel.anchor_bottom = 1.0
	drawer_panel.offset_left = 0
	drawer_panel.offset_right = 0
	drawer_panel.offset_top = 0
	drawer_panel.offset_bottom = 0
	
	# Position fully off-screen to the right initially
	await get_tree().process_frame
	drawer_panel.position.x = get_viewport_rect().size.x

# step 2.430: on a phone the sheet rises to this much of the screen; the rest of the box shows above it
const MOBILE_SHEET_RATIO := 0.95
const BACK_BUTTON_TEXT := "Back"

func _setup_mobile_layout():
	drawer_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	drawer_panel.anchor_left = 0.0
	drawer_panel.anchor_right = 1.0
	drawer_panel.anchor_top = 1.0 - MOBILE_SHEET_RATIO
	drawer_panel.anchor_bottom = 1.0
	drawer_panel.offset_left = 0
	drawer_panel.offset_right = 0
	drawer_panel.offset_top = 0
	drawer_panel.offset_bottom = 0
	
	# Scale fonts for mobile
	title_label.add_theme_font_size_override("font_size", 44)
	optional_label.add_theme_font_size_override("font_size", 44)
	badge_label.add_theme_font_size_override("font_size", 28)
	description_label.add_theme_font_size_override("font_size", 32)
	begin_button.add_theme_font_size_override("font_size", 44)
	begin_button.custom_minimum_size.y = 100

	# step 2.430: Back beside Begin. Back is the quiet one (dark, outlined, grey, narrower) on the left;
	# Begin keeps its look on the right, where the thumb ends. the row takes Begin's place in the column.
	var vbox: Node = begin_button.get_parent()
	var slot: int = begin_button.get_index()
	_button_row = HBoxContainer.new()
	_button_row.name = "ButtonRow"
	_button_row.add_theme_constant_override("separation", 20)
	vbox.add_child(_button_row)
	vbox.move_child(_button_row, slot)
	vbox.remove_child(begin_button)
	var back := Button.new()
	back.name = "BackButton"
	back.text = BACK_BUTTON_TEXT
	back.custom_minimum_size.y = 100
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.size_flags_stretch_ratio = 1.0
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 40)
	back.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
	back.add_theme_color_override("font_pressed_color", Color(0.9, 0.92, 0.96))
	back.add_theme_color_override("font_hover_color", Color(0.72, 0.75, 0.82))
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.09, 0.10, 0.15, 0.95)
	back_style.set_border_width_all(2)
	back_style.border_color = Color(0.55, 0.6, 0.7, 0.55)
	back_style.set_corner_radius_all(6)
	var back_pressed := back_style.duplicate()
	back_pressed.bg_color = Color(0.16, 0.18, 0.25, 1.0)
	back.add_theme_stylebox_override("normal", back_style)
	back.add_theme_stylebox_override("hover", back_style)
	back.add_theme_stylebox_override("pressed", back_pressed)
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.pressed.connect(_on_back_pressed)
	_button_row.add_child(back)
	_button_row.add_child(begin_button)
	begin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	begin_button.size_flags_stretch_ratio = 1.5
	
	# Position fully off-screen below initially
	await get_tree().process_frame
	drawer_panel.position.y = get_viewport_rect().size.y


func _on_back_pressed() -> void:
	if SoundManager and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("ui_click")
	close()

# step 2.316: the text comes first. everything else in the column (description, info rows, begin button) is
# measured, and the image gets the height that's left - never more than the art's own shape at this width,
# never less than DETAIL_IMAGE_MIN_HEIGHT - so the description never needs a scrollbar. when the image is
# shorter than the art, the art is cropped top/bottom, keeping the part the chapter's detail_image_focus asks for.
func _update_detail_image_height() -> void:
	if detail_image == null or drawer_panel == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var anchor_span_v: float = drawer_panel.anchor_bottom - drawer_panel.anchor_top
	if anchor_span_v <= 0.0:
		anchor_span_v = 1.0
	var anchor_span_h: float = drawer_panel.anchor_right - drawer_panel.anchor_left
	if anchor_span_h <= 0.0:
		anchor_span_h = 1.0
	var drawer_h: float = vp_size.y * anchor_span_v
	var usable_w: float = maxf(1.0, vp_size.x * anchor_span_h - DRAWER_CONTENT_H_PADDING)
	var max_ratio: float = DETAIL_IMAGE_MAX_RATIO_MOBILE if _is_mobile else DETAIL_IMAGE_MAX_RATIO_DESKTOP

	# the art's own height at this width (no crop); with no texture yet, the top of the allowed band
	var natural_h: float = drawer_h * max_ratio
	var tex: Texture2D = detail_image.texture
	if tex != null:
		var tex_size: Vector2 = tex.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			natural_h = usable_w * (tex_size.y / tex_size.x)

	# the room the column has, minus everything in it except the image
	var vbox: Control = detail_image.get_parent()
	var inner_h: float = drawer_h
	var panel_style: StyleBox = drawer_panel.get_theme_stylebox("panel")
	if panel_style:
		inner_h -= panel_style.get_minimum_size().y
	var margin: Control = vbox.get_parent()
	if margin is MarginContainer:
		inner_h -= margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")
	var others: float = 0.0
	var shown: int = 0
	for child in vbox.get_children():
		if not (child is Control) or not child.visible:
			continue
		shown += 1
		if child == detail_image:
			continue
		if child is ScrollContainer and child.get_child_count() > 0:
			# a scroll area has no height of its own; what matters is what's inside it
			others += child.get_child(0).get_combined_minimum_size().y
		else:
			others += child.get_combined_minimum_size().y
	if vbox is BoxContainer:
		others += vbox.get_theme_constant("separation") * maxi(0, shown - 1)
	# a few pixels of slack so rounding never brings the scrollbar back
	var room: float = inner_h - others - 6.0

	var target_h: float = minf(natural_h, room)
	detail_image.custom_minimum_size.y = floorf(maxf(DETAIL_IMAGE_MIN_HEIGHT, target_h))
	_layout_image_view()

# step 2.316: the image area keeps its texture (the portal swirl reads it) but doesn't draw it; a child
# view draws the art at its own shape, clipped and shifted by the chapter's focus. the title row and the
# chapter's badges move over the bottom of the image, on a dark fade so they stay readable.
var _image_view: TextureRect = null
var _image_shade: TextureRect = null

func _setup_image_overlay() -> void:
	# the image's size comes from the layout (custom_minimum_size.y), never from the art's own pixels
	detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_image.clip_contents = true
	detail_image.self_modulate.a = 0.0

	_image_view = TextureRect.new()
	_image_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_view.stretch_mode = TextureRect.STRETCH_SCALE
	detail_image.add_child(_image_view)

	var fade := Gradient.new()
	fade.set_color(0, Color(0.06, 0.06, 0.07, 0.0))
	fade.set_color(1, Color(0.06, 0.06, 0.07, 0.88))
	var fade_tex := GradientTexture2D.new()
	fade_tex.gradient = fade
	fade_tex.fill_from = Vector2(0.5, 0.0)
	fade_tex.fill_to = Vector2(0.5, 1.0)
	fade_tex.width = 4
	fade_tex.height = 64
	_image_shade = TextureRect.new()
	_image_shade.texture = fade_tex
	_image_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_image_shade.anchor_left = 0.0
	_image_shade.anchor_right = 1.0
	_image_shade.anchor_top = 0.5
	_image_shade.anchor_bottom = 1.0
	detail_image.add_child(_image_shade)

	# the title row (title + OPTIONAL) goes over the image, and the STORY / SPICY badge joins it
	var title_row: Control = title_label.get_parent()
	title_row.get_parent().remove_child(title_row)
	detail_image.add_child(title_row)
	type_badge.get_parent().remove_child(type_badge)
	title_row.add_child(type_badge)
	# step 2.318: STORY / SPICY straight after the title, then OPTIONAL
	title_row.move_child(type_badge, title_label.get_index() + 1)
	if title_row is BoxContainer:
		title_row.add_theme_constant_override("separation", 16)
	for c in title_row.get_children():
		if c is Control and c != title_label:
			c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title_label.add_theme_constant_override("shadow_offset_x", 2)
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	detail_image.resized.connect(_layout_image_view)

func _layout_image_view() -> void:
	if _image_view == null or detail_image == null:
		return
	var box: Vector2 = detail_image.size
	_image_view.texture = detail_image.texture
	var tex: Texture2D = detail_image.texture
	if tex and tex.get_width() > 0 and box.x > 0.0:
		# the art at the box's width and its own shape (taller than the box when cropped)
		var h: float = box.x * float(tex.get_height()) / float(tex.get_width())
		var w: float = box.x
		if h < box.y:
			# a very short box can't happen with min-height clamps, but if the box is taller, cover it instead
			w = box.y * float(tex.get_width()) / float(tex.get_height())
			h = box.y
		var focus: float = chapter_data.detail_image_focus if chapter_data else 0.5
		_image_view.size = Vector2(w, h)
		_image_view.position = Vector2((box.x - w) * 0.5, (box.y - h) * clampf(focus, 0.0, 1.0))
	# the title row hugs the bottom left of the image
	var title_row: Control = title_label.get_parent()
	if title_row.get_parent() == detail_image:
		var pad: float = 28.0 if _is_mobile else 22.0
		# step 2.318: a long title shrinks to fit next to its badges instead of running off the image
		var others_w: float = 0.0
		var shown: int = 0
		for c in title_row.get_children():
			if c is Control and c.visible:
				shown += 1
				if c != title_label:
					others_w += c.get_combined_minimum_size().x
		if title_row is BoxContainer:
			others_w += title_row.get_theme_constant("separation") * maxi(0, shown - 1)
		UITextScale.fit_width(title_label, box.x - pad * 2.0 - others_w, 0.6)
		var row_h: float = title_row.get_combined_minimum_size().y
		title_row.position = Vector2(pad, box.y - row_h - pad * 0.7)
		title_row.size = Vector2(maxf(0.0, box.x - pad * 2.0), row_h)

func populate(data: MemoryChapterData):
	chapter_data = data
	if not is_node_ready():
		return
	_apply_data()

func _apply_data():
	title_label.text = chapter_data.chapter_name
	optional_badge.visible = chapter_data.is_optional
	description_label.text = chapter_data.chapter_description
	# step 2.419: Replay instead of the usual button text once the chapter has been finished, plus the note
	var finished: bool = ChapterLaunchSequence != null and ChapterLaunchSequence.is_chapter_finished(chapter_data)
	if _begin_text_default.is_empty():
		_begin_text_default = begin_button.text
	begin_button.text = REPLAY_BUTTON_TEXT if finished else _begin_text_default
	_set_replay_note(finished)
	
	# Handle type badge
	var accent_color = Color(0.537255, 0.866667, 1.0) # cyan
	var spicy_color = Color(0.910, 0.329, 0.494) # pinkish red
	
	var badge_style = type_badge.get_theme_stylebox("panel")
	if badge_style:
		badge_style = badge_style.duplicate()
		type_badge.add_theme_stylebox_override("panel", badge_style)
		
	if chapter_data.chapter_type == MemoryChapterData.ChapterType.SPICY:
		badge_label.text = "SPICY"
		badge_label.add_theme_color_override("font_color", spicy_color)
		if badge_style:
			badge_style.border_color = spicy_color
	else:
		badge_label.text = "STORY"
		badge_label.add_theme_color_override("font_color", accent_color)
		if badge_style:
			badge_style.border_color = accent_color
			
	# step 2.312: the insurance form clues, the content tags and the skippable tags, as labelled rows of
	# pills under the description. the scene's own TagsContainer is no longer used.
	tags_container.visible = false
	_build_info_rows()
	# step 2.315: bigger text on PC (the title is already large and keeps its size)
	UITextScale.apply(drawer_panel, UITextScale.memory_box_factor(), [title_label])
	# step 2.318: OPTIONAL looks like the STORY / SPICY badge (same size, outline only) in a neutral grey, so
	# it doesn't shout louder than the title
	_style_optional_badge()
	# step 2.316: wrapped text only knows its height once it has its width: measure again after layout
	_refit_after_layout()
			
	# Load image
	if not chapter_data.detail_image_path.is_empty():
		loaded_texture = load(chapter_data.detail_image_path)
		detail_image.texture = loaded_texture
	elif not chapter_data.thumbnail_path.is_empty():
		loaded_texture = load(chapter_data.thumbnail_path)
		detail_image.texture = loaded_texture
		
	_update_detail_image_height()

# step 2.419: a grey line just above the Begin/Replay button. it lives in the button's VBox, so the image-height
# maths in _update_detail_image_height counts it like any other row.
func _set_replay_note(show: bool) -> void:
	if not show:
		if is_instance_valid(_replay_note):
			_replay_note.visible = false
		return
	if not is_instance_valid(_replay_note):
		_replay_note = Label.new()
		_replay_note.name = "ReplayNote"
		_replay_note.text = REPLAY_NOTE_TEXT
		_replay_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_replay_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_replay_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_replay_note.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		_replay_note.add_theme_font_size_override("font_size", 22 if _is_mobile else 16)
		# step 2.430: on mobile the button sits in a row; the note goes above the row, not inside it
		var anchor: Control = _button_row if is_instance_valid(_button_row) else begin_button
		var vbox: Node = anchor.get_parent()
		vbox.add_child(_replay_note)
		vbox.move_child(_replay_note, anchor.get_index())
	_replay_note.visible = true


func _style_optional_badge() -> void:
	var grey := Color(0.75, 0.78, 0.85)
	# step 2.320: the badges' outline is drawn a little outside each badge (the style's expand margins), so
	# two badges side by side touched. space the title row by that much more.
	var badge_style: StyleBox = type_badge.get_theme_stylebox("panel")
	var extra: float = 0.0
	if badge_style is StyleBoxFlat:
		extra = badge_style.expand_margin_left + badge_style.expand_margin_right
	var title_row: Control = title_label.get_parent()
	var gap: int = (22 if _is_mobile else 16) + int(ceilf(extra))
	title_row.add_theme_constant_override("separation", gap)
	title_row.add_theme_constant_override("h_separation", gap)
	optional_label.add_theme_font_size_override("font_size", badge_label.get_theme_font_size("font_size"))
	optional_label.add_theme_color_override("font_color", grey)
	var src: StyleBox = type_badge.get_theme_stylebox("panel")
	if src:
		var st: StyleBox = src.duplicate()
		if st is StyleBoxFlat:
			st.bg_color = Color(0, 0, 0, 0.35)
			st.border_color = grey
		optional_badge.add_theme_stylebox_override("panel", st)

func _refit_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(self) and not _is_closing:
		_update_detail_image_height()

## step 2.312: three rows under the description.
##   Insurance form - which form fields this chapter gives clues to (hidden when it gives none);
##                    partial clues are marked "(partial)".
##   Content        - adult content the player can't avoid; a single muted "None" when empty.
##   Skippable      - adult content the player can choose to avoid (hidden when empty).
func _build_info_rows() -> void:
	var holder: VBoxContainer = tags_container.get_parent().get_node_or_null("InfoRows")
	if holder:
		for child in holder.get_children():
			child.queue_free()
	else:
		holder = VBoxContainer.new()
		holder.name = "InfoRows"
		holder.add_theme_constant_override("separation", 14 if _is_mobile else 8)
		tags_container.get_parent().add_child(holder)
		tags_container.get_parent().move_child(holder, tags_container.get_index())

	var clues: Array[String] = []
	for f in chapter_data.form_clues:
		clues.append(f)
	for f in chapter_data.partial_form_clues:
		clues.append("%s (partial)" % f)
	if not clues.is_empty():
		_add_info_row(holder, "Insurance form", clues, Color(0.537255, 0.866667, 1.0))

	# step 2.313: adult-content tags are always the spicy pink, whatever the chapter's type, so they read as
	# NSFW at a glance; the clue row stays cyan.
	var accent: Color = Color(0.910, 0.329, 0.494)
	if chapter_data.content_tags.is_empty():
		_add_info_row(holder, "Content", ["None"], Color(0.6, 0.6, 0.65), true)
	else:
		_add_info_row(holder, "Content", chapter_data.content_tags, accent)

	if not chapter_data.skippable_tags.is_empty():
		_add_info_row(holder, "Skippable", chapter_data.skippable_tags, accent)

func _add_info_row(holder: VBoxContainer, heading: String, items: Array, color: Color, muted: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var font = load("res://RobotoMono-VariableFont_wght.ttf")

	row.add_child(_make_heading(heading, font))

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for text in items:
		flow.add_child(_make_pill(String(text), color, muted, font))
	row.add_child(flow)
	holder.add_child(row)

# step 2.314: the row label, with a small (i) after it. the whole label is the button (a big enough
# target on touch); clicking or tapping it opens the row's callout, and again closes it.
func _make_heading(text: String, font) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size.x = 300 if _is_mobile else 170

	var head := Label.new()
	head.text = text
	head.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		head.add_theme_font_override("font", font)
	head.add_theme_font_size_override("font_size", 22 if _is_mobile else 15)
	head.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	box.add_child(head)

	if not INFO_TEXT.has(text):
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return box

	var dot := PanelContainer.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = Color(0, 0, 0, 0)
	dot_style.set_border_width_all(2 if _is_mobile else 1)
	dot_style.border_color = Color(CALLOUT_CYAN, 0.8)
	dot_style.set_corner_radius_all(64)
	dot_style.content_margin_left = 9 if _is_mobile else 6
	dot_style.content_margin_right = 9 if _is_mobile else 6
	dot.add_theme_stylebox_override("panel", dot_style)
	var dot_label := Label.new()
	dot_label.text = "i"
	dot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		dot_label.add_theme_font_override("font", font)
	dot_label.add_theme_font_size_override("font_size", 18 if _is_mobile else 12)
	dot_label.add_theme_color_override("font_color", CALLOUT_CYAN)
	dot.add_child(dot_label)
	box.add_child(dot)

	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.gui_input.connect(_on_heading_input.bind(box, text))
	return box

func _on_heading_input(event: InputEvent, box: Control, text: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		if SoundManager and SoundManager.has_method("play_sfx"):
			SoundManager.play_sfx("ui_click")
		if is_instance_valid(_callout) and _callout_owner == box:
			_close_callout()
		else:
			_open_callout(box, INFO_TEXT[text])

# a small panel in the memory box style under the label (above it if there's no room below), with a
# cyan arrow pointing at the label. only one is open at a time.
func _open_callout(owner: Control, text: String) -> void:
	_close_callout()
	if not _scroll_hooked:
		_scroll_hooked = true
		var scroll = get_node_or_null("DrawerPanel/Margin/VBox/Scroll")
		if scroll is ScrollContainer:
			scroll.get_v_scroll_bar().value_changed.connect(func(_v): _close_callout())

	var vp: Vector2 = get_viewport_rect().size
	var width: float = minf(560.0 if _is_mobile else 380.0, vp.x - 40.0)
	var panel := PanelContainer.new()
	panel.top_level = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.modulate.a = 0.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.172549, 0.184314, 0.266667, 0.98)
	style.set_border_width_all(2)
	style.border_color = CALLOUT_CYAN
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width - 32.0
	var font = load("res://RobotoMono-VariableFont_wght.ttf")
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 24 if _is_mobile else 15)
	label.add_theme_color_override("font_color", Color(0.88, 0.9, 0.95))
	panel.add_child(label)
	UITextScale.apply(panel, UITextScale.memory_box_factor())
	add_child(panel)
	_callout = panel
	_callout_owner = owner

	# one frame for the panel to take its wrapped size, then place it
	await get_tree().process_frame
	if not is_instance_valid(panel) or _callout != panel or not is_instance_valid(owner):
		return
	var r: Rect2 = owner.get_global_rect()
	var below := true
	var pos := Vector2(r.position.x, r.end.y + 12.0)
	if pos.y + panel.size.y > vp.y - 10.0:
		below = false
		pos.y = r.position.y - 12.0 - panel.size.y
	pos.x = clampf(pos.x, 10.0, maxf(10.0, vp.x - panel.size.x - 10.0))
	panel.global_position = pos
	var arrow_x: float = clampf(r.position.x + 14.0 - pos.x, 14.0, panel.size.x - 14.0)
	panel.draw.connect(func():
		var y: float = 0.0 if below else panel.size.y
		var tip: float = -9.0 if below else 9.0
		panel.draw_colored_polygon(PackedVector2Array([
			Vector2(arrow_x - 9.0, y), Vector2(arrow_x + 9.0, y), Vector2(arrow_x, y + tip)]), CALLOUT_CYAN)
	)
	panel.queue_redraw()
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.12)

func _close_callout() -> void:
	if is_instance_valid(_callout):
		_callout.queue_free()
	_callout = null
	_callout_owner = null

# a click or tap anywhere outside the open callout and its label closes it (and still does whatever it
# was going to do)
func _input(event: InputEvent) -> void:
	if not is_instance_valid(_callout):
		return
	if event is InputEventMouseButton and event.pressed:
		var p: Vector2 = event.position
		if _callout.get_global_rect().has_point(p):
			return
		if is_instance_valid(_callout_owner) and _callout_owner.get_global_rect().has_point(p):
			return
		_close_callout()

func _make_pill(text: String, color: Color, muted: bool, font) -> PanelContainer:
	var pill := PanelContainer.new()
	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color(0, 0, 0, 0.4)
	pill_style.set_border_width_all(2)
	pill_style.border_color = Color(color, 0.5) if muted else color
	pill_style.set_corner_radius_all(10)
	pill_style.content_margin_left = 10
	pill_style.content_margin_right = 10
	pill_style.content_margin_top = 4
	pill_style.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", pill_style)

	var pill_label := Label.new()
	pill_label.text = text
	if font:
		pill_label.add_theme_font_override("font", font)
	pill_label.add_theme_font_size_override("font_size", 20 if _is_mobile else 14)
	pill_label.add_theme_color_override("font_color", color)
	pill.add_child(pill_label)
	return pill

func open():
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween().set_parallel(true).bind_node(self)
	
	# Fade in the dimming rect
	_tween.tween_property(dim_rect, "color:a", 0.45, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Slide in panel
	var viewport_size = get_viewport_rect().size
	if _is_mobile:
		var target_y = viewport_size.y * (1.0 - MOBILE_SHEET_RATIO)
		_tween.tween_property(drawer_panel, "position:y", target_y, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		var target_x = viewport_size.x * (1.0 - _desktop_drawer_ratio())
		_tween.tween_property(drawer_panel, "position:x", target_x, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func close():
	if _is_closing:
		return
	_is_closing = true
	_close_callout()
	
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween().set_parallel(true).bind_node(self)
	
	# Fade out dimming rect
	_tween.tween_property(dim_rect, "color:a", 0.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Slide out panel
	var viewport_size = get_viewport_rect().size
	if _is_mobile:
		_tween.tween_property(drawer_panel, "position:y", viewport_size.y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		_tween.tween_property(drawer_panel, "position:x", viewport_size.x, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
	await _tween.finished
	
	# Release VRAM references
	detail_image.texture = null
	loaded_texture = null
	
	emit_signal("drawer_closed")
	queue_free()

func _on_dim_rect_gui_input(event: InputEvent):
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT) and not event.pressed:
		if SoundManager and SoundManager.has_method("play_sfx"):
			SoundManager.play_sfx("ui_click")
		close()

func _on_begin_pressed():
	if SoundManager and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("ui_click")
	emit_signal("begin_pressed", chapter_data)

func _notification(what: int):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_viewport().set_input_as_handled()
		close()

# the portal transition needs the art and where it currently sits on screen.
# both must be read BEFORE close() runs, which drops the drawer's reference.
func get_detail_texture() -> Texture2D:
	if detail_image == null:
		return null
	return detail_image.texture

func get_detail_image_global_rect() -> Rect2:
	if detail_image == null:
		return Rect2()
	return detail_image.get_global_rect()
