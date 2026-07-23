extends Camera2D

signal zoom_changed

@export var target_path: NodePath
var target_node: Node2D

@export_group("Marketing & Debug")
# increase this value (e.g., 1.5
@export var custom_zoom_level: float = 1.0

@export_group("Player Zoom")
# the customizable steps of the
@export var zoom_levels: Array[float] = [1.0, 1.1, 1.2]
# duration of the camera zoom transition.
@export var zoom_tween_seconds: float = 0.25

var _zoom_index: int = 0
var _zoom_tween: Tween = null

func _ready():
	# apply the custom zoom level immediately at index 0
	_apply_zoom(true)

	if target_path:
		target_node = get_node_or_null(target_path)

	position_smoothing_enabled = false

	set_process(false)
	set_physics_process(true)

func can_zoom_in() -> bool:
	var levels = zoom_levels if not zoom_levels.is_empty() else [1.0]
	if levels.size() < 2: return false
	return _zoom_index < levels.size() - 1

func can_zoom_out() -> bool:
	var levels = zoom_levels if not zoom_levels.is_empty() else [1.0]
	if levels.size() < 2: return false
	return _zoom_index > 0

func zoom_in():
	if can_zoom_in():
		_zoom_index += 1
		_apply_zoom()

func zoom_out():
	if can_zoom_out():
		_zoom_index -= 1
		_apply_zoom()

func _apply_zoom(instant: bool = false):
	if _zoom_tween:
		_zoom_tween.kill()

	var levels = zoom_levels if not zoom_levels.is_empty() else [1.0]
	if _zoom_index < 0: _zoom_index = 0
	if _zoom_index >= levels.size(): _zoom_index = levels.size() - 1

	var target_zoom = Vector2.ONE * (custom_zoom_level * levels[_zoom_index])

	if instant:
		zoom = target_zoom
		reset_physics_interpolation()
		zoom_changed.emit()
	else:
		_zoom_tween = create_tween()
		_zoom_tween.tween_property(self, "zoom", target_zoom, zoom_tween_seconds)\
			.set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_OUT)
		_zoom_tween.tween_callback(reset_physics_interpolation)
		_zoom_tween.tween_callback(zoom_changed.emit)

func _physics_process(_delta):
	if is_instance_valid(target_node):
		# snap perfectly to the player in the physics step.
		# --------------- because physics interpolation is on globally, godot will now automatically
		# mooth the visual rendering of
		global_position = target_node.global_position

func snap_to_target():
	if not target_node: return
	global_position = target_node.global_position
	reset_physics_interpolation()

func set_camera_limits(left: int, right: int, top: int, bottom: int):
	limit_enabled = true
	limit_smoothed = false

	limit_left = left
	limit_right = right
	limit_top = top
	limit_bottom = bottom

	reset_physics_interpolation()
