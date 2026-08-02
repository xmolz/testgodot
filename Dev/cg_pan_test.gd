# cg_pan_test.gd — dev-only harness for the vertical CG pan (low framing -> face).
# one tall image, scrolled. no camera: this is a position tween on the image itself, which is how
# VN engines do it.
#
# framing is expressed in SOURCE pixels — the y of the top edge of the visible 16:9 window — so the
# inspector numbers line up 1:1 with the ruler printed on pan_test_target_2560x3840.png.
#
# does NOT reuse AdvancedConversationOverlay's CGLayer: that one is KEEP_ASPECT_COVERED, which crops
# centred with no way to offset the crop.
extends Control

const DIALOGUE_PATH := "res://Dev/cg_pan_test.dialogue"

@export_file("*.png") var image_path: String = "res://Dev/pan_test_target_2560x3840.png"

# top edge of the visible window, in source px. 0 = top of the image.
@export var start_src_y: float = 2400.0
@export var end_src_y: float = 0.0

@export_range(0.2, 12.0, 0.1) var duration: float = 3.0

# subtle push-in across the move. 1.0 = off. ~1.05 reads as a camera rather than a slide.
@export_range(1.0, 1.5, 0.01) var start_zoom: float = 1.0
@export_range(1.0, 1.5, 0.01) var end_zoom: float = 1.0

@export_enum("Sine InOut", "Cubic InOut", "Linear") var easing: int = 0

# turn off to judge the framing clean, without the balloon eating the bottom of the shot
@export var show_dialogue: bool = true

var _cg: TextureRect
var _readout: Label
var _tex: Texture2D = null
var _balloon: Node = null
var _pan_tween: Tween = null
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
	print("cg pan test: %s  source %dx%d  fit %.3f  max_src_y %.0f" % [
		image_path, int(_tex.get_size().x), int(_tex.get_size().y), _fit_scale(), _max_src_y_at(1.0)
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


func _max_src_y_at(zoom: float) -> float:
	if _tex == null:
		return 0.0
	var eff: float = _fit_scale() * zoom
	if eff <= 0.0:
		return 0.0
	return max(0.0, _tex.get_size().y - get_viewport_rect().size.y / eff)


func _apply_frame(src_y: float, zoom: float) -> void:
	if _tex == null or not is_instance_valid(_cg):
		return
	var eff: float = _fit_scale() * zoom
	var disp: Vector2 = _tex.get_size() * eff
	var clamped: float = clampf(src_y, 0.0, _max_src_y_at(zoom))
	_cg.size = disp
	_cg.position = Vector2((get_viewport_rect().size.x - disp.x) * 0.5, -clamped * eff)
	_cur_src_y = clamped
	_cur_zoom = zoom
	_refresh_readout()


# ****************************[mutations called from the dialogue file]
func pan() -> void:
	_play(start_src_y, end_src_y, start_zoom, end_zoom)


func pan_reverse() -> void:
	_play(end_src_y, start_src_y, end_zoom, start_zoom)


func snap_to_start() -> void:
	_kill_pan()
	_apply_frame(start_src_y, start_zoom)


func snap_to_end() -> void:
	_kill_pan()
	_apply_frame(end_src_y, end_zoom)


func _kill_pan() -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null


func _play(a_y: float, b_y: float, a_z: float, b_z: float) -> void:
	_kill_pan()
	_apply_frame(a_y, a_z)
	_pan_tween = create_tween()
	match easing:
		1:
			_pan_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		2:
			_pan_tween.set_trans(Tween.TRANS_LINEAR)
		_:
			_pan_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_method(
		func(t: float) -> void: _apply_frame(lerpf(a_y, b_y, t), lerpf(a_z, b_z, t)),
		0.0,
		1.0,
		duration
	)


# ****************************[readout]
func _refresh_readout() -> void:
	if not is_instance_valid(_readout):
		return
	var lines: PackedStringArray = PackedStringArray()
	if _tex == null:
		_readout.text = "cg pan test: NO IMAGE\n%s" % image_path
		return

	var eff: float = _fit_scale() * _cur_zoom
	var window_h_src: float = get_viewport_rect().size.y / eff
	var crisp: String = "under native, crisp" if eff <= 1.0 else "OVER NATIVE - softening"

	lines.append("CG PAN TEST   source %dx%d" % [int(_tex.get_size().x), int(_tex.get_size().y)])
	lines.append("sampling  fit %.3f  x zoom %.2f  = %.3f   (%s)" % [_fit_scale(), _cur_zoom, eff, crisp])
	lines.append("window    src y %d .. %d   (height %d src px)" % [
		int(round(_cur_src_y)), int(round(_cur_src_y + window_h_src)), int(round(window_h_src))
	])
	lines.append("framings  start %d  ->  end %d   max %d" % [
		int(start_src_y), int(end_src_y), int(round(_max_src_y_at(_cur_zoom)))
	])
	lines.append("move      %.1fs   %s   zoom %.2f -> %.2f" % [
		duration,
		["Sine InOut", "Cubic InOut", "Linear"][clampi(easing, 0, 2)],
		start_zoom,
		end_zoom
	])
	lines.append("P play   O reverse   1 start frame   2 end frame   [ / ] duration   R restart")
	_readout.text = "\n".join(lines)


# ****************************[dev keys]
# uses _input, not _unhandled_input: the balloon swallows unhandled input by design.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return

	match k.keycode:
		KEY_P:
			pan()
		KEY_O:
			pan_reverse()
		KEY_1, KEY_KP_1:
			snap_to_start()
		KEY_2, KEY_KP_2:
			snap_to_end()
		KEY_BRACKETLEFT:
			duration = max(duration - 0.25, 0.2)
			_refresh_readout()
		KEY_BRACKETRIGHT:
			duration = min(duration + 0.25, 12.0)
			_refresh_readout()
		KEY_R:
			snap_to_start()
			if show_dialogue:
				_start_dialogue()
		_:
			return
	get_viewport().set_input_as_handled()
