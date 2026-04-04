extends CanvasLayer

var is_hovering: bool = false
var _rotation_angle: float = 0.0
var _current_radius: float = 8.0

func _ready():
	layer = 128 # Keep it above everything
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta):
	# Follow the mouse
	var mouse_pos = get_viewport().get_mouse_position()
	$Control.global_position = mouse_pos

	# Smoothly interpolate radius based on hover state
	var target_radius = 24.0 if is_hovering else 12.0
	_current_radius = lerp(_current_radius, target_radius, delta * 15.0)

	# Rotate if hovering
	if is_hovering:
		_rotation_angle += delta * PI # Rotate half a circle per second
	else:
		_rotation_angle = lerp_angle(_rotation_angle, 0.0, delta * 10.0)

	$Control.queue_redraw()

func set_hover_state(hovering: bool):
	is_hovering = hovering
