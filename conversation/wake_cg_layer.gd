# wake_cg_layer.gd — pannable wake-up CG, promoted from Dev/cg_pan_test.gd (step 2.4).
# sits on canvas layer 70, UNDER the conversation overlay at 75: the overlay's eyelid blink
# opens onto this layer's CG. the dialogue reaches it through the overlay's extra_game_states.
#
# framing is the CENTRE of the visible window in source px, plus a zoom. centre framing is
# stable when zoom changes mid-move; corner framing is not (it clamps itself into reversals).
# zoom 1.0 = the whole 16:9 frame fills the viewport, no travel. zoom 2.0 on a 3840-wide
# source is exactly 1:1 sampling.
class_name WakeCGLayer
extends CanvasLayer

@export_file("*.png", "*.jpg") var cg_path: String = "res://Backgrounds/CG/chapter2_wake.png"

# frames: (centre_x, centre_y) in source px, plus zoom. values tuned in the dev harness.
@export var start_cx: float = 2048.0
@export var start_cy: float = 1376.0
@export_range(1.0, 4.0, 0.01) var start_zoom: float = 2.0

@export var end_cx: float = 2880.0
@export var end_cy: float = 540.0
@export_range(1.0, 4.0, 0.01) var end_zoom: float = 2.0

@export var reveal_cx: float = 1920.0
@export var reveal_cy: float = 1080.0
@export_range(1.0, 4.0, 0.01) var reveal_zoom: float = 1.0

@export_range(0.2, 12.0, 0.1) var pan_duration: float = 1.2
@export_range(0.2, 12.0, 0.1) var reveal_duration: float = 1.0

var _root: Control = null
var _cg: TextureRect = null
var _tex: Texture2D = null
var _pan_tween: Tween = null


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# opaque backdrop: swallows stray clicks so the faded memory box underneath cannot be
	# clicked mid-sequence, and guarantees black behind a clamped frame.
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.color = Color(0.0, 0.0, 0.0, 1.0)
	_root.add_child(backdrop)

	_cg = TextureRect.new()
	_cg.name = "CG"
	_cg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cg.stretch_mode = TextureRect.STRETCH_SCALE
	_cg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_cg)

	# armed but invisible until the dialogue calls stage_wake_cg() under the blackout
	visible = false

	if ResourceLoader.exists(cg_path):
		_tex = load(cg_path)
	if _tex:
		_cg.texture = _tex
	else:
		push_error("wake_cg_layer: missing CG at %s" % cg_path)


# ****************************[dialogue-facing mutations]
# called from the dialogue, under the blackout: snap to the opening frame and show.
func stage_wake_cg() -> void:
	snap_to_start()
	visible = true


func pan() -> void:
	_play(Vector3(start_cx, start_cy, start_zoom), Vector3(end_cx, end_cy, end_zoom), pan_duration)


func reveal() -> void:
	_play(Vector3(end_cx, end_cy, end_zoom), Vector3(reveal_cx, reveal_cy, reveal_zoom), reveal_duration)


func snap_to_start() -> void:
	_kill_pan()
	_apply_frame(start_cx, start_cy, start_zoom)


# ****************************[launch pipeline hooks]
# the launch sequence awaits this so teardown never races a running tween
func wait_for_pan() -> void:
	if _pan_tween and _pan_tween.is_valid() and _pan_tween.is_running():
		await _pan_tween.finished


func fade_out(duration: float = 0.7) -> void:
	_kill_pan()
	if not is_instance_valid(_root):
		return
	var t := create_tween()
	t.tween_property(_root, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await t.finished


# ****************************[framing maths] (same model as the dev harness)
func _fit_scale() -> float:
	if _tex == null:
		return 1.0
	return get_viewport().get_visible_rect().size.x / float(_tex.get_size().x)


func _eff(zoom: float) -> float:
	return _fit_scale() * zoom


func _window_src(zoom: float) -> Vector2:
	var e: float = _eff(zoom)
	if e <= 0.0:
		return Vector2.ZERO
	return get_viewport().get_visible_rect().size / e


func _apply_frame(cx: float, cy: float, zoom: float) -> void:
	if _tex == null or not is_instance_valid(_cg):
		return
	var src: Vector2 = _tex.get_size()
	var e: float = _eff(zoom)
	var win: Vector2 = _window_src(zoom)
	var half: Vector2 = win * 0.5

	var ax: float = src.x * 0.5 if win.x >= src.x else clampf(cx, half.x, src.x - half.x)
	var ay: float = src.y * 0.5 if win.y >= src.y else clampf(cy, half.y, src.y - half.y)

	_cg.size = src * e
	_cg.position = -(Vector2(ax, ay) - half) * e


func _kill_pan() -> void:
	if _pan_tween and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null


# frames are packed as Vector3(centre_x, centre_y, zoom)
func _play(a: Vector3, b: Vector3, secs: float) -> void:
	_kill_pan()
	_apply_frame(a.x, a.y, a.z)
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pan_tween.tween_method(
		func(x: float) -> void:
			var f: Vector3 = a.lerp(b, x)
			_apply_frame(f.x, f.y, f.z),
		0.0,
		1.0,
		secs
	)
