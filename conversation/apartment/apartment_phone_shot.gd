extends Control
## step 2.186: the "Late Delivery" phone shot. Fiona's phone (conversation/phone/phone_cg.tscn)
## held over the apartment floor, with the pizza pamphlet lying on the floor behind it.
## focus_pamphlet() is a rack focus then a push-in: the phone drifts toward the camera, out of
## focus and away, then the view zooms in on the pamphlet. The phone never translates, so
## the painting's cut-off top and bottom stay hidden.
## During the push-in the far floor
## (Backgrounds/apartment_floor_far.png) scales up while the close floor
## (Backgrounds/apartment_floor_close.png) dissolves in once the zoom lands, lined up exactly,
## because the close painting is the far one scaled by ZOOM about ZOOM_CENTER.
## Shown by the conversation overlay as a scene CG; dialogue drives it with
## do scene_cg_call("select_contact", [1]) / do scene_cg_call("focus_pamphlet").

const DESIGN_SIZE := Vector2(3840, 2160)
## close floor = far floor scaled by ZOOM and turned by ZOOM_ROTATION about ZOOM_CENTER
## (measured from the two paintings, in design pixels).
const ZOOM := 1.5723
const ZOOM_ROTATION := -0.0048
const ZOOM_CENTER := Vector2(2147.0, -6.1)


@onready var _frame: Node2D = $Frame
@onready var _far_view: Node2D = $Frame/FarView
@onready var _close_view: Node2D = $Frame/CloseView
@onready var _pamphlet_view: Node2D = $Frame/PamphletView
@onready var phone: Control = $PhoneCG

## 0 = far shot, 1 = zoomed onto the pamphlet. Tweened by focus_pamphlet(); can also be set
## directly (Inspector or code) to scrub the zoom.
@export_range(0.0, 1.0, 0.001) var focus := 0.0:
	set(v):
		focus = v
		if is_node_ready():
			_apply_focus()

## 0 = far floor, 1 = the sharper close floor painting. focus_pamphlet() dissolves it in at
## the end of the zoom, when it lines up exactly with the zoomed far floor.
@export_range(0.0, 1.0, 0.01) var close_mix := 0.0:
	set(v):
		close_mix = v
		if is_node_ready():
			_close_view.modulate.a = v

var _tween: Tween


func _ready() -> void:
	resized.connect(_fit)
	_fit()
	_apply_focus()


## Rack focus from the phone to the floor, then push in on the pamphlet. await it in code;
## dialogue waits for it.
func focus_pamphlet(duration: float = 1.6) -> void:
	await rack_to_floor(0.9)
	await _tween_property("focus", 1.0, duration)
	await _tween_property("close_mix", 1.0, 0.35)


## The phone drifts toward the camera, out of focus and away, leaving the floor.
func rack_to_floor(duration: float = 0.9) -> void:
	await phone.defocus_away(duration)


## Undo rack_to_floor(): the phone comes back into focus.
func rack_to_phone(duration: float = 0.7) -> void:
	await phone.bring_back(duration)


## Zoom back out to the far shot (the phone stays wherever it is).
func unfocus(duration: float = 1.2) -> void:
	await _tween_property("close_mix", 0.0, 0.2)
	await _tween_property("focus", 0.0, duration)


func select_contact(index: int) -> void:
	phone.select_contact(index)


func step_selection(delta: int) -> void:
	phone.step_selection(delta)


func _tween_property(property: String, target: float, duration: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, property, target, duration)
	await _tween.finished


func _apply_focus() -> void:
	# far floor and pamphlet zoom together about ZOOM_CENTER; the close floor never moves
	var s := lerpf(1.0, ZOOM, focus)
	var r := ZOOM_ROTATION * focus
	for view: Node2D in [_far_view, _pamphlet_view]:
		view.scale = Vector2(s, s)
		view.rotation = r
		view.position = ZOOM_CENTER - (ZOOM_CENTER * s).rotated(r)
	_close_view.modulate.a = close_mix


func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s := maxf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_frame.scale = Vector2(s, s)
	_frame.position = (size - DESIGN_SIZE * s) * 0.5
