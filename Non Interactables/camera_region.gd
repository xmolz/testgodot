extends Area2D
class_name CameraRegion

@export var is_active_on_start: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	collision_layer = 0
	collision_mask = 1

	body_entered.connect(_on_body_entered)

	if is_active_on_start:
		await get_tree().process_frame
		_apply_limits()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		_apply_limits()

func _apply_limits():
	if not collision_shape or not collision_shape.shape is RectangleShape2D:
		push_warning("CameraRegion requires a CollisionShape2D with a RectangleShape2D.")
		return

	var shape = collision_shape.shape as RectangleShape2D

	var global_pos = collision_shape.global_position
	var extents = shape.size / 2.0

	var left = int(global_pos.x - extents.x)
	var right = int(global_pos.x + extents.x)
	var top = int(global_pos.y - extents.y)
	var bottom = int(global_pos.y + extents.y)

	var camera = get_viewport().get_camera_2d()
	if camera and camera.has_method("set_camera_limits"):
		camera.set_camera_limits(left, right, top, bottom)
