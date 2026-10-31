extends Control
## step 2.299 (dev test): the car art with every swappable part, using levels/car/car_rig.gd and the
## patches made by Dev/car_test/car_parts_cutter.gd. open Dev/car_test/car_expression_test.tscn, F6.
## keys: 1-9 step through the options of slot 1-9 (listed on screen), Tab = the next 9 slots,
##       0 = every slot to its default, Z = zoom in on the face and back, B = bump, O = show the boxes.

const RIG_SCRIPT := preload("res://levels/car/car_rig.gd")

@export var vibration_px: float = 0.6
@export var bump_strength: float = 10.0
## zoom level for Z (2 shows the art at about 1:1 on a 1080p window)
@export var face_zoom: float = 2.0

var _rig: Control
var _label: Label
var _slots: Array = []
var _page := 0   # step 2.387: which nine slots the number keys reach (Tab)
var _zoomed := false
var _zoom_tween: Tween
var _outlines := false
var _vib_t := 0.0
var _bump_y := 0.0
var _bump_v := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	# a plain sky behind the see-through windows
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.color = Color(0.70, 0.80, 0.92)
	add_child(sky)

	_rig = RIG_SCRIPT.new()
	add_child(_rig)

	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 5)
	add_child(_label)

	_slots = _rig.get_slots()
	_update_label()


func _update_label() -> void:
	if not _rig.loaded:
		_label.text = "No parts yet - run Dev/car_test/car_parts_cutter.gd (File > Run) first."
		return
	var lines := PackedStringArray()
	for i in range(_page * 9, mini(_slots.size(), _page * 9 + 9)):
		var slot: String = _slots[i]
		var opts: Array = _rig.get_options(slot)
		var cur: String = _rig.get_current(slot)
		lines.append("%d  %s:  %s   (%d/%d)" % [i - _page * 9 + 1, slot, cur, opts.find(cur) + 1, opts.size()])
	lines.append("0  all defaults")
	lines.append("")
	lines.append("Tab more slots (page %d of %d)   Z zoom   B bump   O boxes" % [_page + 1, _page_count()])
	_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_0:
		_rig.apply("default")
		_update_label()
	elif k == KEY_TAB:
		_page = (_page + 1) % _page_count()
		_update_label()
	elif k >= KEY_1 and k <= KEY_9:
		var n: int = _page * 9 + k - KEY_1
		if n < _slots.size():
			var slot: String = _slots[n]
			var opts: Array = _rig.get_options(slot)
			var next: String = opts[(opts.find(_rig.get_current(slot)) + 1) % opts.size()]
			_rig.set_part(slot, next)
			_update_label()
	elif k == KEY_Z:
		_toggle_zoom()
	elif k == KEY_B:
		_bump_v += 38.0 * bump_strength
	elif k == KEY_O:
		_outlines = not _outlines
		_rig.set_outlines_visible(_outlines)


func _page_count() -> int:
	return maxi(1, ceili(_slots.size() / 9.0))


func _toggle_zoom() -> void:
	_zoomed = not _zoomed
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	var target_focus: Vector2 = _rig.canvas * 0.5
	if _zoomed:
		# the face: between the eyes and the mouth boxes (or the first slot's box)
		var face := Rect2()
		for slot in _slots:
			if String(slot).contains("eyes") or String(slot).contains("mouth"):
				var r := Rect2(_rig.get_slot_rect(slot))
				face = r if face.size == Vector2.ZERO else face.merge(r)
		if face.size == Vector2.ZERO and not _slots.is_empty():
			face = Rect2(_rig.get_slot_rect(_slots[0]))
		target_focus = face.get_center()
	_zoom_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_zoom_tween.tween_property(_rig, "zoom", face_zoom if _zoomed else 1.0, 0.6)
	_zoom_tween.tween_property(_rig, "focus", target_focus, 0.6)


func _process(delta: float) -> void:
	# the same road vibration and bump spring as the car ride, applied to the whole rig
	_bump_v += (-_bump_y * 180.0 - _bump_v * 14.0) * delta
	_bump_y += _bump_v * delta
	_vib_t += delta
	var vib := Vector2(
		(sin(_vib_t * 37.0) + sin(_vib_t * 23.0)) * 0.5 * vibration_px,
		(sin(_vib_t * 41.0) * 0.6 + sin(_vib_t * 17.0) * 0.4) * vibration_px)
	_rig.offset = vib + Vector2(0.0, _bump_y)
