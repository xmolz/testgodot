# cg_pan_test.gd — dev-only harness for CG camera moves (low framing -> face).
# no camera node: this is a position tween on the image itself, which is how VN engines do it.
#
# framing is the CENTRE of the visible window, in source pixels, plus a zoom. centre framing is
# stable when the zoom changes mid-move; corner framing is not, and silently clamped itself into a
# reversal the first time it was tried.
#
# does NOT reuse AdvancedConversationOverlay's CGLayer: that one is KEEP_ASPECT_COVERED, which crops
# centred with no way to offset the crop.
extends Control

const DIALOGUE_PATH := "res://Dev/cg_pan_test.dialogue"
const NUDGE := 20.0
const NUDGE_FINE := 5.0

@export_file("*.png") var image_path: String = "res://Dev/cg_pan_ref_3840x2160.png"

# CENTRE of the visible window, in source px
@export var start_cx: float = 2048.0
@export var start_cy: float = 1376.0
@export var end_cx: float = 2880.0
@export var end_cy: float = 540.0

# on a 16:9 source this is what creates the travel in the first place. 1.0 = whole frame, no move.
# zoom 2.0 on a 3840-wide source is exactly 1:1 sampling.
@export_range(1.0, 4.0, 0.01) var start_zoom: float = 2.0
@export_range(1.0, 4.0, 0.01) var end_zoom: float = 2.0

@export_range(0.2, 12.0, 0.1) var duration: float = 1.2

@export_enum("Sine InOut", "Cubic InOut", "Linear") var easing: int = 0

# turn off to judge the framing clean, without the balloon eating the bottom of the shot
@export var show_dialogue: bool = true

@export var show_minimap: bool = true

var _cg: TextureRect
var _readout: Label
var _minimap: Control
var _tex: Texture2D = null
var _balloon: Node = null
var _pan_tween: Tween = null

var _cur_cx: float = 0.0
var _cur_cy: float = 0.0
var _cur_zoom: float = 1.0
var _want_cx: float = 0.0
var _want_cy: float = 0.0


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

	_minimap = Control.new()
	_minimap.name = "Minimap"
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.visible = show_minimap
	_minimap.draw.connect(_draw_minimap)
	add_child(_minimap)


func _load_image() -> void:
	if not ResourceLoader.exists(image_path):
		push_warning("cg pan test: missing image %s" % image_path)
		return
	_tex = load(image_path)
	if _tex == null:
		push_warning("cg pan test: could not load %s" % image_path)
		return
	_cg.texture = _tex
	var src: Vector2 = _tex.get_size()
	var box_w: float = 280.0
	_minimap.size = Vector2(box_w, box_w * src.y / src.x)
	_minimap.position = Vector2(get_viewport_rect().size.x - box_w - 24.0, 20.0)
	print("cg pan test: %s  source %dx%d  fit %.3f" % [image_path, int(src.x), int(src.y), _fit_scale()])


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


func _window_src(zoom: float) -> Vector2:
	var e: float = _eff(zoom)
	if e <= 0.0:
		return Vector2.ZERO
	return get_viewport_rect().size / e


func _apply_frame(cx: float, cy: float, zoom: float) -> void:
	if _tex == null or not is_instance_valid(_cg):
		return
	var src: Vector2 = _tex.get_size()
	var e: float = _eff(zoom)
	var win: Vector2 = _window_src(zoom)
	var half: Vector2 = win * 0.5

	_want_cx = cx
	_want_cy = cy

	var ax: float = src.x * 0.5 if win.x >= src.x else clampf(cx, half.x, src.x - half.x)
	var ay: float = src.y * 0.5 if win.y >= src.y else clampf(cy, half.y, src.y - half.y)

	_cg.size = src * e
	_cg.position = -(Vector2(ax, ay) - half) * e

	_cur_cx = ax
	_cur_cy = ay
	_cur_zoom = zoom
	_refresh_readout()
	if is_instance_valid(_minimap):
		_minimap.queue_redraw()


# ****************************[mutations called from the dialogue file]
func pan() -> void:
	_play(Vector3(start_cx, start_cy, start_zoom), Vector3(end_cx, end_cy, end_zoom))


func pan_reverse() -> void:
	_play(Vector3(end_cx, end_cy, end_zoom), Vector3(start_cx, start_cy, start_zoom))


func snap_to_start() -> void:
	_kill_pan()
	_apply_frame(start_cx, start_cy, start_zoom)


func snap_to_end() -> void:
	_kill_pan()
	_apply_frame(end_cx, end_cy, end_zoom)


func _kill_pan() -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null


# frames are packed as Vector3(centre_x, centre_y, zoom)
func _play(a: Vector3, b: Vector3) -> void:
	_kill_pan()
	_apply_frame(a.x, a.y, a.z)
	_pan_tween = create_tween()
	match easing:
		1:
			_pan_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
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
	_apply_frame(_cur_cx + dx, _cur_cy + dy, _cur_zoom)


func _zoom_by(dz: float) -> void:
	_kill_pan()
	_apply_frame(_cur_cx, _cur_cy, clampf(_cur_zoom + dz, 1.0, 4.0))


func _store_start() -> void:
	start_cx = _cur_cx
	start_cy = _cur_cy
	start_zoom = _cur_zoom
	print("cg pan test: START  cx %.0f  cy %.0f  zoom %.2f" % [start_cx, start_cy, start_zoom])
	_refresh_readout()


func _store_end() -> void:
	end_cx = _cur_cx
	end_cy = _cur_cy
	end_zoom = _cur_zoom
	print("cg pan test: END    cx %.0f  cy %.0f  zoom %.2f" % [end_cx, end_cy, end_zoom])
	_refresh_readout()


# ****************************[minimap]
func _draw_minimap() -> void:
	if _tex == null or not is_instance_valid(_minimap):
		return
	var src: Vector2 = _tex.get_size()
	var box: Vector2 = _minimap.size
	var k: float = box.x / src.x
	_minimap.draw_rect(Rect2(Vector2.ZERO, box), Color(0.0, 0.0, 0.0, 0.55), true)
	_minimap.draw_rect(Rect2(Vector2.ZERO, box), Color(0.55, 1.0, 0.7, 0.85), false, 2.0)
	var win: Vector2 = _window_src(_cur_zoom)
	var tl: Vector2 = Vector2(_cur_cx, _cur_cy) - win * 0.5
	var r := Rect2(tl * k, win * k)
	_minimap.draw_rect(r, Color(1.0, 0.55, 0.35, 0.22), true)
	_minimap.draw_rect(r, Color(1.0, 0.55, 0.35, 1.0), false, 2.0)


# ****************************[readout]
func _refresh_readout() -> void:
	if not is_instance_valid(_readout):
		return
	if _tex == null:
		_readout.text = "cg pan test: NO IMAGE\n%s" % image_path
		return

	var src: Vector2 = _tex.get_size()
	var e: float = _eff(_cur_zoom)
	var win: Vector2 = _window_src(_cur_zoom)
	var half: Vector2 = win * 0.5
	var crisp: String = "under native, crisp" if e <= 1.0 else "OVER NATIVE - softening"
	var clamped: bool = not (is_equal_approx(_want_cx, _cur_cx) and is_equal_approx(_want_cy, _cur_cy))

	var lines: PackedStringArray = PackedStringArray()
	lines.append("CG PAN TEST   source %dx%d" % [int(src.x), int(src.y)])
	lines.append("sampling  fit %.3f x zoom %.2f = %.3f   (%s)" % [_fit_scale(), _cur_zoom, e, crisp])
	lines.append("window    %d x %d src px" % [int(round(win.x)), int(round(win.y))])
	if clamped:
		lines.append("centre    %d , %d   CLAMPED from %d , %d" % [
			int(round(_cur_cx)), int(round(_cur_cy)), int(round(_want_cx)), int(round(_want_cy))
		])
	else:
		lines.append("centre    %d , %d" % [int(round(_cur_cx)), int(round(_cur_cy))])
	lines.append("legal     x %d..%d   y %d..%d" % [
		int(round(half.x)), int(round(src.x - half.x)),
		int(round(half.y)), int(round(src.y - half.y))
	])
	lines.append("START     %d , %d  zoom %.2f" % [int(start_cx), int(start_cy), start_zoom])
	lines.append("END       %d , %d  zoom %.2f" % [int(end_cx), int(end_cy), end_zoom])
	lines.append("move      %.2fs   %s" % [duration, ["Sine InOut", "Cubic InOut", "Linear"][clampi(easing, 0, 2)]])
	lines.append("arrows move (shift = fine)   , / . zoom   S set start   E set end   M minimap")
	lines.append("P play   O reverse   1 start   2 end   [ / ] duration   R restart")
	_readout.text = "\n".join(lines)


# ****************************[dev keys]
# uses _input, not _unhandled_input: the balloon swallows unhandled input by design.
# arrow keys deliberately do not filter echo, so holding a key scrubs the framing.
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
		KEY_M:
			if is_instance_valid(_minimap):
				_minimap.visible = not _minimap.visible
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
