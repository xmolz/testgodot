extends Camera2D

@export var target_path: NodePath
var target_node: Node2D

@export_group("Marketing & Debug")
## Increase this value (e.g., 1.5 or 2.0) to zoom the camera in closer for GIFs.
@export var custom_zoom_level: float = 1.0

func _ready():
	# Apply the custom zoom level immediately
	zoom = Vector2(custom_zoom_level, custom_zoom_level)

	if target_path:
		target_node = get_node_or_null(target_path)

	position_smoothing_enabled = false

	set_process(false)
	set_physics_process(true)

func _physics_process(_delta):
	if is_instance_valid(target_node):
		# 3. Snap perfectly to the player in the physics step.
		# Because Physics Interpolation is ON globally, Godot will now automatically 
		# smooth the visual rendering of BOTH the player and the camera together!
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
