extends CanvasLayer

var is_hovering: bool = false
var _rotation_angle: float = 0.0
var _current_radius: float = 8.0

func _ready():
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta):
	var mouse_pos = get_viewport().get_mouse_position()
	var needs_redraw = false

	# only update if position changed
	if $Control.global_position != mouse_pos:
		$Control.global_position = mouse_pos
		needs_redraw = true

	# smoothly interpolate radiu
	var target_radius = 24.0 if is_hovering else 12.0
	if abs(_current_radius - target_radius) > 0.1:
		_current_radius = lerp(_current_radius, target_radius, delta * 15.0)
		needs_redraw = true

	# rotate only if hovering, otherwise settle back to 0
	if is_hovering:
		_rotation_angle += delta * PI
		needs_redraw = true
	else:
		if abs(_rotation_angle) > 0.01:
			_rotation_angle = lerp_angle(_rotation_angle, 0.0, delta * 10.0)
			needs_redraw = true

	# only force the gpu to
	if needs_redraw:
		$Control.queue_redraw()

func set_hover_state(hovering: bool):
	is_hovering = hovering
