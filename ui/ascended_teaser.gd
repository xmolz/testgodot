# res://ui/ascended_teaser.gd
# step 2.425: a screen between the logo splash and the loading screen, showing what The Ascended tier's
# message looks like in the game: the message on the left, a character sprite on the right (Fiona for
# now), and a caption pointing at the sprite. built in code, no scene. click, any key, or ~8 s moves on.
# step 2.426: a CanvasLayer with a full-rect Control inside. as a bare Control under Boot (a plain Node)
# the root had no size, every label was 0 px wide, and the text wrapped one letter per line.
extends CanvasLayer

signal teaser_finished

const FONT_PATH := "res://Fonts/VarelaRound-Regular.ttf"
# step 2.427: the sprite: a rig's parts map, its expressions file, an expression name from that file (or a raw
# parts list), and whether to mirror it so it faces the quote. Jayce's "stunned" is his face at Fiona's flash.
const SPRITE_PARTS := "res://characters/jayce/parts/jayce_parts.json"
const SPRITE_EXPRESSIONS := "res://characters/jayce/jayce_expressions.json"
const SPRITE_EXPRESSION := "stunned"
const SPRITE_FACES_LEFT := true

const MESSAGE := "Wanna print a message out to the world and display it here? Check out the Ascended tier on our Patreon!"
const ATTRIBUTION := "\u2014 Lewgend"
const SPRITE_CAPTION := "Your customized sprite goes here  \u279c"
const HINT := "click or press any key to continue"

const AUTO_ADVANCE_SECONDS := 8.0
const FADE_SECONDS := 0.5

var _done: bool = false
var _font: Font = null
var _root: Control = null


func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	var mobile := OS.has_feature("mobile")

	# step 2.426: the full-screen control everything hangs off; it also takes the click
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_root_gui_input)
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 120 if mobile else 90)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	_root.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	# left: the message, its attribution, and the caption pointing right at the sprite
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 18)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)

	var quote := _label("\u201c" + MESSAGE + "\u201d", 44 if mobile else 34, Color(0.92, 0.92, 0.92))
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(quote)

	var by := _label(ATTRIBUTION, 30 if mobile else 24, Color(0.835294, 0.94902, 0.572549))
	by.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(by)

	var gap := Control.new()
	gap.custom_minimum_size.y = 70 if mobile else 50
	left.add_child(gap)

	var caption := _label(SPRITE_CAPTION, 28 if mobile else 22, Color(0.75, 0.78, 0.85))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	left.add_child(caption)

	# right: the sprite, composed from the rig parts like any character in a conversation
	var right := CenterContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)

	var sprite := TextureRect.new()
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sprite.custom_minimum_size = Vector2(420, 640) if mobile else Vector2(380, 600)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if FileAccess.file_exists(SPRITE_PARTS):
		# an expression name resolves through the rig's expressions file; anything else is a parts list already
		var parts: String = SPRITE_EXPRESSION
		if FileAccess.file_exists(SPRITE_EXPRESSIONS):
			var named = JSON.parse_string(FileAccess.get_file_as_string(SPRITE_EXPRESSIONS))
			if named is Dictionary and named.has(SPRITE_EXPRESSION):
				parts = String(named[SPRITE_EXPRESSION])
		sprite.texture = ActorRigComposer.compose(SPRITE_PARTS, parts)
	sprite.flip_h = SPRITE_FACES_LEFT
	right.add_child(sprite)

	# bottom: the hint
	var hint := _label(HINT, 22 if mobile else 16, Color(0.5, 0.5, 0.55))
	hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -56
	hint.offset_bottom = -24
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, FADE_SECONDS)
	get_tree().create_timer(AUTO_ADVANCE_SECONDS).timeout.connect(_finish)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if _font:
		l.add_theme_font_override("font", _font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch) and event.is_pressed():
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_SECONDS)
	await tween.finished
	teaser_finished.emit()
	queue_free()
