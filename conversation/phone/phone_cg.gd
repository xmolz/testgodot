extends Control
## step 2.185: a "live" CG of Fiona's flip phone.
## Your painted phone (Backgrounds/CG/phone_cg.png, screen hole transparent) is drawn over
## the screen, a live LCD rendered by phone_screen.gd, so the painted bezel masks the
## edges. Everything sits in a 3840 x 2160 design frame that fills the screen the same way
## the conversation overlay's CG layer does (keep aspect, covered).
##
## Controllable on purpose:
##  - the Rig (phone + screen + glow) has a pose: rig_offset / rig_rotation_deg / rig_zoom,
##    tweenable with move_to(), plus an optional idle hand sway;
##  - the painting is cut off at the top and bottom of the frame, so whatever the pose, the
##    rig zooms in just enough to keep those cut edges off screen (hide_cut_edges);
##  - the whole phone sits in a CanvasGroup with a depth-of-field blur (blur, defocus_away());
##  - the screen has its own API (select_contact, step_selection, set_contacts, ...);
##  - backlight can fade with fade_backlight().
## The movement functions are awaitable, so dialogue can later call them with
## "do phone.move_to(...)" once the overlay can host a scene as a CG.

const DESIGN_SIZE := Vector2(3840, 2160)
const REST_POSITION := Vector2(1920, 1080)

@export_group("Rig pose")
## Offset from the rest position, in design pixels (3840 x 2160 space).
@export var rig_offset := Vector2.ZERO
@export_range(-45.0, 45.0, 0.1) var rig_rotation_deg := 0.0
@export_range(0.25, 3.0, 0.01) var rig_zoom := 1.0

## Keep the painting's cut-off top and bottom edges outside the frame by zooming in as
## little as needed (moves, tilts and the idle sway would otherwise expose them).
@export var hide_cut_edges := true
## Where the painting is cut, as x ranges in art-local pixels (art centre = 0): the opaque
## span of its top row and of its bottom row. Re-measure if phone_cg.png is repainted.
@export var cut_top_span := Vector2(-972, 472)
@export var cut_bottom_span := Vector2(-593, 962)

@export_group("Idle sway")
@export var sway_enabled := true
## Peak drift in design pixels (x, y).
@export var sway_amount := Vector2(10, 7)
@export_range(0.0, 3.0, 0.01) var sway_rotation_deg := 0.35
## Cycles per second.
@export_range(0.0, 2.0, 0.01) var sway_speed := 0.28

@export_group("Screen")
@export_range(0.0, 1.0, 0.01) var backlight := 1.0:
	set(v):
		backlight = v
		if is_node_ready():
			_apply_backlight()
## Opacity of the blue light spill over the phone at full backlight.
@export_range(0.0, 1.0, 0.01) var glow_strength := 0.16:
	set(v):
		glow_strength = v
		if is_node_ready():
			_apply_backlight()

## Depth-of-field blur on the whole phone, as a radius in 1080p pixels (0 = sharp).
@export_range(0.0, 40.0, 0.1) var blur := 0.0:
	set(v):
		blur = v
		if is_node_ready():
			_apply_blur()

@export_group("Backdrop")
## Turn off when another scene draws its own background behind the phone
## (for example conversation/apartment/apartment_phone_shot.tscn).
@export var show_backdrop := true:
	set(v):
		show_backdrop = v
		if is_node_ready():
			$Frame/Backdrop.visible = v

@onready var _frame: Node2D = $Frame
@onready var _focus: CanvasGroup = $Frame/Focus
@onready var _rig: Node2D = $Frame/Focus/Rig
@onready var _screen_sprite: Sprite2D = $Frame/Focus/Rig/Screen
@onready var _glow: Sprite2D = $Frame/Focus/Rig/ScreenGlow
@onready var _viewport: SubViewport = $ScreenViewport
@onready var screen: Control = $ScreenViewport/PhoneScreen

var _time := 0.0
var _pose_tween: Tween
var _light_tween: Tween
var _focus_tween: Tween


func _ready() -> void:
	_screen_sprite.texture = _viewport.get_texture()
	$Frame/Backdrop.visible = show_backdrop
	resized.connect(_fit)
	_fit()
	_apply_backlight()
	_apply_blur()
	_apply_pose()


func _process(delta: float) -> void:
	_time += delta
	_apply_pose()


## Tween the phone to a pose. await it to wait for the move to finish.
func move_to(offset: Vector2, rotation_deg: float = 0.0, zoom: float = 1.0, duration: float = 0.6) -> void:
	if _pose_tween and _pose_tween.is_valid():
		_pose_tween.kill()
	if duration <= 0.0:
		rig_offset = offset
		rig_rotation_deg = rotation_deg
		rig_zoom = zoom
		return
	_pose_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pose_tween.tween_property(self, "rig_offset", offset, duration)
	_pose_tween.tween_property(self, "rig_rotation_deg", rotation_deg, duration)
	_pose_tween.tween_property(self, "rig_zoom", zoom, duration)
	await _pose_tween.finished


func reset_pose(duration: float = 0.6) -> void:
	await move_to(Vector2.ZERO, 0.0, 1.0, duration)


## The phone drifts toward the camera, out of focus and away: for cutting from the phone to
## something behind it. Use bring_back() to undo.
func defocus_away(duration: float = 0.9) -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_focus_tween.tween_property(self, "blur", 22.0, duration)
	_focus_tween.tween_property(self, "rig_zoom", rig_zoom * 1.12, duration)
	_focus_tween.tween_property(_focus, "modulate:a", 0.0, duration)
	await _focus_tween.finished


func bring_back(duration: float = 0.7) -> void:
	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_property(self, "blur", 0.0, duration)
	_focus_tween.tween_property(self, "rig_zoom", 1.0, duration)
	_focus_tween.tween_property(_focus, "modulate:a", 1.0, duration)
	await _focus_tween.finished


func fade_backlight(level: float, duration: float = 0.3) -> void:
	if _light_tween and _light_tween.is_valid():
		_light_tween.kill()
	_light_tween = create_tween()
	_light_tween.tween_property(self, "backlight", clampf(level, 0.0, 1.0), duration)
	await _light_tween.finished


func select_contact(index: int) -> void:
	screen.selected_index = index


func step_selection(delta: int) -> void:
	screen.step_selection(delta)


func set_contacts(names: PackedStringArray) -> void:
	screen.contacts = names


func set_clock(text: String) -> void:
	screen.clock_text = text


func set_battery(level: float) -> void:
	screen.battery_level = level


func _apply_pose() -> void:
	var sway := Vector2.ZERO
	var sway_rot := 0.0
	if sway_enabled and sway_speed > 0.0:
		var t := _time * TAU * sway_speed
		sway = Vector2(sin(t) * sway_amount.x, sin(t * 0.77 + 1.3) * sway_amount.y)
		sway_rot = sin(t * 0.61 + 0.4) * sway_rotation_deg
	var centre := REST_POSITION + rig_offset + sway
	var rot := deg_to_rad(rig_rotation_deg + sway_rot)
	var zoom := rig_zoom
	if hide_cut_edges:
		zoom = maxf(zoom, _min_zoom_hiding_cuts(centre, rot))
	_rig.position = centre
	_rig.rotation = rot
	_rig.scale = Vector2.ONE * zoom


## Smallest zoom at which both ends of the top cut stay above the frame and both ends of
## the bottom cut stay below it, for the given rig centre and rotation.
func _min_zoom_hiding_cuts(centre: Vector2, rot: float) -> float:
	var half_h := DESIGN_SIZE.y * 0.5
	var need := 0.0
	for x in [cut_top_span.x, cut_top_span.y]:
		var dy := Vector2(x, -half_h).rotated(rot).y # negative: points up
		if dy < 0.0:
			need = maxf(need, centre.y / -dy)
	for x in [cut_bottom_span.x, cut_bottom_span.y]:
		var dy := Vector2(x, half_h).rotated(rot).y # positive: points down
		if dy > 0.0:
			need = maxf(need, (DESIGN_SIZE.y - centre.y) / dy)
	return need


func _apply_blur() -> void:
	var mat := _focus.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("blur", blur)


func _apply_backlight() -> void:
	var mat := _screen_sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("backlight", backlight)
	_glow.modulate.a = glow_strength * backlight


func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var s := maxf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	_frame.scale = Vector2(s, s)
	_frame.position = (size - DESIGN_SIZE * s) * 0.5
