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
var _is_mobile: bool = false

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

func _setup_mobile_layout():
	drawer_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	drawer_panel.anchor_left = 0.0
	drawer_panel.anchor_right = 1.0
	drawer_panel.anchor_top = 1.0 - 0.60
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
	
	# Position fully off-screen below initially
	await get_tree().process_frame
	drawer_panel.position.y = get_viewport_rect().size.y

func _update_detail_image_height() -> void:
	if detail_image == null or drawer_panel == null:
		return
	# derive the drawer's own rect from its anchors, so this stays correct for both
	# the desktop side drawer and the mobile bottom sheet without duplicating literals.
	var vp_size: Vector2 = get_viewport_rect().size
	var anchor_span_v: float = drawer_panel.anchor_bottom - drawer_panel.anchor_top
	if anchor_span_v <= 0.0:
		anchor_span_v = 1.0
	var anchor_span_h: float = drawer_panel.anchor_right - drawer_panel.anchor_left
	if anchor_span_h <= 0.0:
		anchor_span_h = 1.0
	var drawer_h: float = vp_size.y * anchor_span_v
	var usable_w: float = maxf(1.0, vp_size.x * anchor_span_h - DRAWER_CONTENT_H_PADDING)

	var min_ratio: float = DETAIL_IMAGE_MIN_RATIO_MOBILE if _is_mobile else DETAIL_IMAGE_MIN_RATIO_DESKTOP
	var max_ratio: float = DETAIL_IMAGE_MAX_RATIO_MOBILE if _is_mobile else DETAIL_IMAGE_MAX_RATIO_DESKTOP
	var reserve: float = CONTENT_RESERVE_MOBILE if _is_mobile else CONTENT_RESERVE_DESKTOP

	# prefer the exact height at which the source art shows with no cropping.
	# with no texture yet, fall back to the top of the allowed band.
	var natural_h: float = drawer_h * max_ratio
	var tex: Texture2D = detail_image.texture
	if tex != null:
		var tex_size: Vector2 = tex.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			natural_h = usable_w * (tex_size.y / tex_size.x)

	var target_h: float = clampf(natural_h, drawer_h * min_ratio, drawer_h * max_ratio)
	# on short windows, never push the text and begin button out of the panel.
	target_h = minf(target_h, maxf(DETAIL_IMAGE_MIN_HEIGHT, drawer_h - reserve))
	detail_image.custom_minimum_size.y = floorf(maxf(DETAIL_IMAGE_MIN_HEIGHT, target_h))

func populate(data: MemoryChapterData):
	chapter_data = data
	if not is_node_ready():
		return
	_apply_data()

func _apply_data():
	title_label.text = chapter_data.chapter_name
	optional_badge.visible = chapter_data.is_optional
	description_label.text = chapter_data.chapter_description
	
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
			
	# Handle content tags
	for child in tags_container.get_children():
		child.queue_free()
		
	if chapter_data.content_tags.is_empty():
		tags_container.visible = false
	else:
		tags_container.visible = true
		for tag_text in chapter_data.content_tags:
			var pill = PanelContainer.new()
			var pill_style = StyleBoxFlat.new()
			pill_style.bg_color = Color(0, 0, 0, 0.4)
			pill_style.border_width_left = 2
			pill_style.border_width_top = 2
			pill_style.border_width_right = 2
			pill_style.border_width_bottom = 2
			pill_style.border_color = spicy_color if chapter_data.chapter_type == MemoryChapterData.ChapterType.SPICY else accent_color
			pill_style.corner_radius_top_left = 10
			pill_style.corner_radius_top_right = 10
			pill_style.corner_radius_bottom_left = 10
			pill_style.corner_radius_bottom_right = 10
			pill_style.content_margin_left = 10
			pill_style.content_margin_right = 10
			pill_style.content_margin_top = 4
			pill_style.content_margin_bottom = 4
			
			pill.add_theme_stylebox_override("panel", pill_style)
			
			var pill_label = Label.new()
			pill_label.text = tag_text
			pill_label.add_theme_font_override("font", load("res://RobotoMono-VariableFont_wght.ttf"))
			pill_label.add_theme_font_size_override("font_size", 20 if _is_mobile else 14)
			pill_label.add_theme_color_override("font_color", spicy_color if chapter_data.chapter_type == MemoryChapterData.ChapterType.SPICY else accent_color)
			
			pill.add_child(pill_label)
			tags_container.add_child(pill)
			
	# Load image
	if not chapter_data.detail_image_path.is_empty():
		loaded_texture = load(chapter_data.detail_image_path)
		detail_image.texture = loaded_texture
	elif not chapter_data.thumbnail_path.is_empty():
		loaded_texture = load(chapter_data.thumbnail_path)
		detail_image.texture = loaded_texture
		
	_update_detail_image_height()

func open():
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween().set_parallel(true).bind_node(self)
	
	# Fade in the dimming rect
	_tween.tween_property(dim_rect, "color:a", 0.45, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Slide in panel
	var viewport_size = get_viewport_rect().size
	if _is_mobile:
		var target_y = viewport_size.y * 0.40
		_tween.tween_property(drawer_panel, "position:y", target_y, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		var target_x = viewport_size.x * (1.0 - _desktop_drawer_ratio())
		_tween.tween_property(drawer_panel, "position:x", target_x, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func close():
	if _is_closing:
		return
	_is_closing = true
	
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
