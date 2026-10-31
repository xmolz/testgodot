# chapterbutton.gd
extends Button

# this signal is emitted when
signal chapter_selected(data: MemoryChapterData)

const LockIconScript = preload("res://ui/LockIcon.gd")
const UITextScale = preload("res://ui/UITextScale.gd")
## step 2.308: game flag prefix that remembers the player has opened a newly unlocked chapter's description
const SEEN_PREFIX := "chapter_seen:"
## step 2.309: locked tiles sit a shade darker than the memory box panel, so they recede instead of
## being the darkest thing on screen; the padlock is a softened version of the memory box cyan.
const LOCKED_BG := Color(0.085, 0.092, 0.14)
const LOCKED_LOCK := Color(0.537, 0.867, 1.0, 0.55)
## step 2.309: chapters of a location that isn't open yet are plain empty slots (no padlock), so a row of
## them reads as "more to come" rather than a wall of locks. true = padlocks there too.
const LOCKS_IN_UNKNOWN_LOCATIONS := false
const NEW_GLOW := Color(1.35, 1.6, 1.75)

# ********** node references
@onready var chapter_name_label: Label = $MarginContainer/VBoxContainer/Label
@onready var chapter_image_rect: TextureRect = $MarginContainer/VBoxContainer/TextureRect

# ******************* data
var chapter_data: MemoryChapterData
## step 2.308: true while this chapter is newly unlocked and its description hasn't been opened yet
var is_new: bool = false
var _pulse: Tween
var _badge: Label
var _pre_glow_style: StyleBox

func _ready():
	# connect our own "pressed" signal to a handler function.
	self.pressed.connect(_on_pressed)

	# ************************[touch scroll fix]
	# buttons default to stop, which
	# changing this to pass allows
	self.mouse_filter = Control.MOUSE_FILTER_PASS

	# --------------(mobile scaling for chapter button)
	if OS.has_feature("mobile"):
		self.custom_minimum_size = Vector2(240, 175)
		chapter_name_label.add_theme_font_size_override("font_size", 24)
		# provide 56 pixels of vertical
		chapter_name_label.custom_minimum_size.y = 56

func _on_pressed():
	# step 2.308: opening a new chapter's description counts as having seen it
	if is_new:
		_mark_seen()
	# when this button is pressed, emit our custom signal,
	# passing our own chapter_data along with it.
	emit_signal("chapter_selected", chapter_data)

## step 2.308: is this chapter locked? (a chapter with no unlock_flag is always open.
## the "unlock all chapters" dev toggle on Main opens everything.)
static func is_chapter_locked(data: MemoryChapterData) -> bool:
	if data.unlock_flag.is_empty():
		return false
	# step 2.324: the dev "unlock all" only opens chapters that have something to play; empty placeholders
	# stay locked, so the box doesn't fill up with TEMPLATE tiles
	if Engine.get_meta("dev_unlock_all_chapters", false) and is_playable(data):
		return false
	return not Flags.get_game_flag(data.unlock_flag)

## step 2.324: does this chapter have anything to play yet (a level, or an in-place scene)?
static func is_playable(data: MemoryChapterData) -> bool:
	return not data.scene_path_to_load.strip_edges().is_empty() or not data.intro_overlay_path.strip_edges().is_empty()

## step 2.308: the per-chapter "seen" flag, keyed by the chapter's resource file
static func seen_key(data: MemoryChapterData) -> String:
	var id: String = data.resource_path.get_file().trim_suffix(".tres")
	if id.is_empty():
		id = data.chapter_name
	return SEEN_PREFIX + id

# this function takes memorychapterdata and
# step 2.308: force_locked = the whole location is still locked (its chapters show as "?")
func populate(data: MemoryChapterData, force_locked: bool = false):
	self.chapter_data = data
	var locked: bool = force_locked or is_chapter_locked(chapter_data)

	# ////////////////////////(1. set the visuals)
	# step 2.309: a locked chapter's name stays hidden until it opens (a space keeps the label's height,
	# so locked and open buttons line up)
	chapter_name_label.text = " " if locked else chapter_data.chapter_name
	# step 2.318: names stay on one line (a second line squeezed that tile's picture smaller than the rest);
	# a long name shrinks its font to fit instead (see _fit_name)
	chapter_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	chapter_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_fit_name.call_deferred()

	# step 2.308: a locked chapter shows a cyan padlock on a dark tile instead of its picture
	# (which also isn't loaded, so it costs no VRAM)
	if locked:
		_show_locked_tile(LOCKS_IN_UNKNOWN_LOCATIONS or not force_locked)
	elif not chapter_data.thumbnail_path.is_empty() and ResourceLoader.exists(chapter_data.thumbnail_path):
		chapter_image_rect.texture = load(chapter_data.thumbnail_path)
		# step 2.312: a tile is ~250 px wide; a full-size CG here costs ~30 MB of VRAM per chapter
		var tex: Texture2D = chapter_image_rect.texture
		if tex and tex.get_width() > 1024:
			push_warning("ChapterButton: the cover %s is %dx%d. select it in the FileSystem dock, set Import > Process > Size Limit to 640 and reimport." % [chapter_data.thumbnail_path, tex.get_width(), tex.get_height()])

	# if chapter is SPICY, apply pinkish-red styling
	if chapter_data.chapter_type == MemoryChapterData.ChapterType.SPICY and not locked:
		var normal_style = get_theme_stylebox("normal").duplicate()
		var hover_style = get_theme_stylebox("hover").duplicate()
		
		var spicy_color = Color(0.910, 0.329, 0.494)
		normal_style.border_color = spicy_color
		
		hover_style.border_color = spicy_color
		hover_style.bg_color = Color(spicy_color.r, spicy_color.g, spicy_color.b, 0.1)
		
		add_theme_stylebox_override("normal", normal_style)
		add_theme_stylebox_override("hover", hover_style)
		
		chapter_name_label.add_theme_color_override("font_color", spicy_color.lerp(Color.WHITE, 0.3))

	# step 2.319: every picture fills the same area (like the locked tiles), whatever its own shape, and
	# the tile has no resting border (hover, press and the NEW glow still show one)
	chapter_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chapter_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_drop_resting_border()
	# step 2.321: a button draws its outline under its contents, so the picture covered the outline's
	# sides. a see-through frame on top of everything now draws the outline instead.
	_make_frame()

	# ------------------- 2. handle locked/unlocked state
	if locked:
		# if the chapter is locked, make it look disabled.
		self.disabled = true
		# step 2.309: the tile and padlock colours do the greying now (an extra modulate turned the tile black)
		return

	# step 2.308: unlocked by a flag and never opened yet = newly unlocked. it glows until clicked.
	if not chapter_data.unlock_flag.is_empty() and not Engine.get_meta("dev_unlock_all_chapters", false) \
			and not Flags.get_game_flag(seen_key(chapter_data)):
		_start_new_highlight()

# step 2.318: after layout (and after the memory box has scaled its text), shrink a long name to fit
func _fit_name() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or chapter_name_label == null:
		return
	# step 2.319: the name strip is always one full-size line tall, so a name that shrinks to fit never
	# gives its picture extra height (which made that tile's picture bigger than the others)
	var font: Font = chapter_name_label.get_theme_font("font")
	var full_size: int = int(chapter_name_label.get_meta("fit_base_size", chapter_name_label.get_theme_font_size("font_size")))
	if font:
		chapter_name_label.custom_minimum_size.y = ceilf(font.get_height(full_size))
	chapter_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITextScale.fit_width(chapter_name_label, chapter_name_label.size.x - 8.0, 0.7)

var _frame: Panel = null

func _make_frame() -> void:
	if _frame:
		return
	_frame = Panel.new()
	_frame.name = "OutlineFrame"
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	# the button redraws whenever its state changes (hover, press, focus, the NEW glow); follow it
	draw.connect(func(): _update_frame.call_deferred())
	_update_frame.call_deferred()

# the outline of whatever state the button is in, without its fill
func _update_frame() -> void:
	if not is_instance_valid(_frame):
		return
	var state := "normal"
	match get_draw_mode():
		DRAW_HOVER:
			state = "hover"
		DRAW_PRESSED:
			state = "pressed"
		DRAW_HOVER_PRESSED:
			state = "hover_pressed"
		DRAW_DISABLED:
			state = "disabled"
	if state == "normal" and has_focus():
		state = "focus"
	var src: StyleBox = get_theme_stylebox(state)
	if src is StyleBoxFlat:
		var outline: StyleBoxFlat = src.duplicate()
		outline.draw_center = false
		outline.shadow_size = 0
		_frame.add_theme_stylebox_override("panel", outline)
	else:
		_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

# step 2.319: no border while resting (normal and disabled); hover, pressed and focus keep theirs
func _drop_resting_border() -> void:
	for state in ["normal", "disabled"]:
		var style: StyleBox = get_theme_stylebox(state)
		if style is StyleBoxFlat:
			var flat: StyleBoxFlat = style.duplicate()
			flat.set_border_width_all(0)
			add_theme_stylebox_override(state, flat)

func _show_locked_tile(with_lock: bool = true) -> void:
	chapter_image_rect.texture = null
	var bg := ColorRect.new()
	bg.color = LOCKED_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	chapter_image_rect.add_child(bg)
	if not with_lock:
		return
	var lock: Control = LockIconScript.new()
	lock.color = LOCKED_LOCK
	lock.hole_color = LOCKED_BG
	lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	# a margin above and below so the lock sits comfortably in the tile
	lock.anchor_top = 0.15
	lock.anchor_bottom = 0.85
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter_image_rect.add_child(lock)

func _start_new_highlight() -> void:
	is_new = true
	# a brighter, thicker cyan border
	_pre_glow_style = get_theme_stylebox("normal")
	var glow_style: StyleBox = _pre_glow_style.duplicate()
	if glow_style is StyleBoxFlat:
		glow_style.border_color = Color(0.75, 0.95, 1.0)
		glow_style.set_border_width_all(4)
		add_theme_stylebox_override("normal", glow_style)
	# a small NEW tag in the corner
	_badge = Label.new()
	_badge.text = "NEW"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	_badge.add_theme_color_override("font_outline_color", Color(0.06, 0.07, 0.11))
	_badge.add_theme_constant_override("outline_size", 6)
	_badge.add_theme_font_size_override("font_size", 28 if OS.has_feature("mobile") else 20)
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(_badge)
	# a slow brightness pulse
	_pulse = create_tween().set_loops()
	_pulse.tween_property(self, "modulate", NEW_GLOW, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(self, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _mark_seen() -> void:
	is_new = false
	Flags.set_game_flag(seen_key(chapter_data), true)
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	modulate = Color.WHITE
	if _pre_glow_style:
		add_theme_stylebox_override("normal", _pre_glow_style)
	if is_instance_valid(_badge):
		_badge.queue_free()

func _exit_tree():
	chapter_image_rect.texture = null
