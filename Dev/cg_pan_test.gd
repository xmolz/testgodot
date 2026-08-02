# cg_pan_test.gd — dev-only harness for CG camera moves (low framing -> face).
# no camera node: this is a position tween on the image itself, which is how VN engines do it.
#
# framing is the TOP-LEFT CORNER of the visible window, in source pixels, plus a zoom. on a tall CG
# you only move y. on a 16:9 CG you zoom in past 1.0 first, which is what creates the travel, and
# then you move in both axes.
#
# does NOT reuse AdvancedConversationOverlay's CGLayer: that one is KEEP_ASPECT_COVERED, which crops
# centred with no way to offset the crop.
extends Control

const DIALOGUE_PATH := "res://Dev/cg_pan_test.dialogue"
const NUDGE := 20.0
const NUDGE_FINE := 5.0

@export_file("*.png") var image_path: String = "res://Dev/cg_pan_ref_3840x2160.png"

# top-left of the visible window, in source px
@export var start_src_x: float = 750.0
@export var start_src_y: float = 840.0
@export var end_src_x: float = 1920.0
@export var end_src_y: float = 0.0

# on a 16:9 source this is what creates the travel in the first place. 1.0 = whole frame, no move.
@export_range(1.0, 4.0, 0.01) var start_zoom: float = 2.0
@export_range(1.0, 4.0, 0.01) var end_zoom: float = 2.0

@export_range(0.2, 12.0, 0.1) var duration: float = 1.4

@export_enum("Sine InOut", "Cubic InOut", "Linear") var easing: int = 0

# turn off to judge the framing clean, without the balloon eating the bottom of the shot
@export var show_dialogue: bool = true

var _cg: TextureRect
var _readout: Label
var _tex: Texture2D = null
var _balloon: Node = null
var _pan_tween: Tween = null
var _cur_src_x: float = 0.0
var _cur_src_y: float = 0.0
var _cur_zoom: float = 1.0


func _ready() -> void:
	_build_ui()
	_load_image()
	snap_to_start()
	if show_dialogue:
		_start_dialogue()


# ****************************[setup]
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.color = Color(0.05, 0.05, 0.06, 1.0)
	add_child(bg)

	_cg = TextureRect.new()
	_cg.name = "CG"
	_cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cg.stretch_mode = TextureRect.STRETCH_SCALE
	_cg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cg)

	_readout = Label.new()
	_readout.name = "Readout"
	_readout.position = Vector2(24, 20)
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := load("res://RobotoMono-VariableFont_wght.ttf")
	if mono:
		_readout.add_theme_font_override("font", mono)
	_readout.add_theme_font_size_override("font_size", 18)
	_readout.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7, 1.0))
	_readout.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_readout.add_theme_constant_override("outline_size", 6)
	add_child(_readout)


func _load_image() -> void:
	if not ResourceLoader.exists(image_path):
		push_warning("cg pan test: missing image %s" % image_path)
		return
	_tex = load(image_path)
	if _tex == null:
		push_warning("cg pan test: could not load %s" % image_path)
		return
	_cg.texture = _tex
	print("cg pan test: %s  source %dx%d  fit %.3f" % [
		image_path, int(_tex.get_size().x), int(_tex.get_size().y), _fit_scale()
	])


func _start_dialogue() -> void:
	if is_instance_valid(_balloon):
		_balloon.queue_free()
		_balloon = null
	var dlg = load(DIALOGUE_PATH)
	if dlg == null:
		push_warning("cg pan test: could not load %s" % DIALOGUE_PATH)
		return
	_balloon = DialogueManager.show_dialogue_balloon_scene(
		preload("res://conversation/conversationballoon.tscn"),
		dlg,
		"start",
		[self]
	)


# ****************************[framing maths]
func _fit_scale() -> float:
	if _tex == null:
		return 1.0
	return get_viewport_rect().size.x / float(_tex.get_size().x)


func _eff(zoom: float) -> float:
	return _fit_scale() * zoom


func _max_src(zoom: float) -> Vector2:
	if _tex == null:
		return Vector2.ZERO
	var e: float = _eff(zoom)
	if e <= 0.0:
		return Vector2.ZERO
	return Vector2(
		max(0.0, _tex.get_size().x - get_viewport_rect().size.x / e),
		max(0.0, _tex.get_size().y - get_viewport_rect().size.y / e)
	)


func _apply_frame(src_x: float, src_y: float, zoom: float) -> void:
	if _tex == null or not is_instance_valid(_cg):
		return
	var e: float = _eff(zoom)
	var limit: Vector2 = _max_src(zoom)
	var cx: float = clampf(src_x, 0.0, limit.x)
	var cy: float = clampf(src_y, 0.0, limit.y)
	_cg.size = _tex.get_size() * e
	_cg.position = Vector2(-cx * e, -cy * e)
	_cur_src_x = cx
	_cur_src_y = cy
	_cur_zoom = zoom
	_refresh_readout()


# ****************************[mutations called from the dialogue file]
func pan() -> void:
	_play(Vector3(start_src_x, start_src_y, start_zoom), Vector3(end_src_x, end_src_y, end_zoom))


func pan_reverse() -> void:
	_play(Vector3(end_src_x, end_src_y, end_zoom), Vector3(start_src_x, start_src_y, start_zoom))


func snap_to_start() -> void:
	_kill_pan()
	_apply_frame(start_src_x, start_src_y, start_zoom)


func snap_to_end() -> void:
	_kill_pan()
	_apply_frame(end_src_x, end_src_y, end_zoom)


func _kill_pan() -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null


# frames are packed as Vector3(src_x, src_y, zoom)
func _play(a: Vector3, b: Vector3) -> void:
	_kill_pan()
	_apply_frame(a.x, a.y, a.z)
	_pan_tween = create_tween()
	match easing:
		1:
			_pan_tween.set_trans(Tween.TRANS_SUBIC if "TRANS_SUBIC" in Tween else Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		2:
			_pan_tween.set_trans(Tween.TRANS_LINEAR)
		_:
			_pan_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_method(
		func(t: float) -> void:
			var f: Vector3 = a.lerp(b, t)
			_apply_frame(f.x, f.y, f.z),
		0.0,
		1.0,
		duration
	)


# ****************************[live framing tool]
func _nudge(dx: float, dy: float) -> void:
	_kill_pan()
	_apply_frame(_cur_src_x + dx, _cur_src_y + dy, _cur_zoom)


func _zoom_by(dz: float) -> void:
	_kill_pan()
	_apply_frame(_cur_src_x, _cur_src_y, clampf(_cur_zoom + dz, 1.0, 4.0))


func _store_start() -> void:
	start_src_x = _cur_src_x
	start_src_y = _cur_src_y
	start_zoom = _cur_zoom
	print("cg pan test: START  src_x %.0f  src_y %.0f  zoom %.2f" % [start_src_x, start_src_y, start_zoom])
	_refresh_readout()


func _store_end() -> void:
	end_src_x = _cur_src_x
	end_src_y = _cur_src_y
	end_zoom = _cur_zoom
	print("cg pan test: END    src_x %.0f  src_y %.0f  zoom %.2f" % [end_src_x, end_src_y, end_zoom])
	_refresh_readout()


# ****************************[readout]
func _refresh_readout() -> void:
	if not is_instance_valid(_readout):
		return
	if _tex == null:
		_readout.text = "cg pan test: NO IMAGE\n%s" % image_path
		return

	var e: float = _eff(_cur_zoom)
	var limit: Vector2 = _max_src(_cur_zoom)
	var win: Vector2 = get_viewport_rect().size / e
	var crisp: String = "under native, crisp" if e <= 1.0 else "OVER NATIVE - softening"

	var lines: PackedStringArray = PackedStringArray()
	lines.append("CG PAN TEST   source %dx%d" % [int(_tex.get_size().x), int(_tex.get_size().y)])
	lines.append("sampling  fit %.3f x zoom %.2f = %.3f   (%s)" % [_fit_scale(), _cur_zoom, e, crisp])
	lines.append("window    %d x %d src px   at %d , %d   (max %d , %d)" % [
		int(round(win.x)), int(round(win.y)),
		int(round(_cur_src_x)), int(round(_cur_src_y)),
		int(round(limit.x)), int(round(limit.y))
	])
	lines.append("START     %d , %d  zoom %.2f" % [int(start_src_x), int(start_src_y), start_zoom])
	lines.append("END       %d , %d  zoom %.2f" % [int(end_src_x), int(end_src_y), end_zoom])
	lines.append("move      %.2fs   %s" % [duration, ["Sine InOut", "Cubic InOut", "Linear"][clampi(easing, 0, 2)]])
	lines.append("arrows move (shift = fine)   , / . zoom   S set start   E set end")
	lines.append("P play   O reverse   1 start   2 end   [ / ] duration   R restart")
	_readout.text = "\n".join(lines)


# ****************************[dev keys]
# uses _input, not _unhandled_input: the balloon swallows unhandled input by design.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed:
		return
	var step: float = NUDGE_FINE if k.shift_pressed else NUDGE

	match k.keycode:
		KEY_LEFT:
			_nudge(-step, 0.0)
		KEY_RIGHT:
			_nudge(step, 0.0)
		KEY_UP:
			_nudge(0.0, -step)
		KEY_DOWN:
			_nudge(0.0, step)
		KEY_COMMA:
			_zoom_by(-0.05)
		KEY_PERIOD:
			_zoom_by(0.05)
		KEY_S:
			_store_start()
		KEY_E:
			_store_end()
		KEY_P:
			pan()
		KEY_O:
			pan_reverse()
		KEY_1, KEY_KP_1:
			snap_to_start()
		KEY_2, KEY_KP_2:
			snap_to_end()
		KEY_BRACKETLEFT:
			duration = max(duration - 0.1, 0.2)
			_refresh_readout()
		KEY_BRACKETRIGHT:
			duration = min(duration + 0.1, 12.0)
			_refresh_readout()
		KEY_R:
			snap_to_start()
			if show_dialogue:
				_start_dialogue()
		_:
			return
	get_viewport().set_input_as_handled()
