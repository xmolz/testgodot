extends CanvasLayer

var is_hovering: bool = false
var is_exit_mode: bool = false
var exit_direction: int = 1
var _exit_bob_time: float = 0.0
var _over_ui: bool = false
var _rotation_angle: float = 0.0
var _current_radius: float = 8.0

func _ready():
	# UI layering contract: 128 is reserved for the custom cursor. All other CanvasLayers must stay <= 125.
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta):
	var mouse_pos = get_viewport().get_mouse_position()
	var needs_redraw = false

	# UI precedence: any Control under the mouse that accepts mouse input (verb
	# panel, inventory, zoom/menu buttons, popups) wins the regular cursor back.
	# our own Control is mouse_filter IGNORE, so it never counts.
	var over_ui_now: bool = get_viewport().gui_get_hovered_control() != null
	if over_ui_now != _over_ui:
		_over_ui = over_ui_now
		needs_redraw = true

	# only update if position changed
	if $Control.global_position != mouse_pos:
		$Control.global_position = mouse_pos
		needs_redraw = true

	if is_exit_mode and not _over_ui:
		# exit-zone mode: the cursor IS the bobbing arrow; crosshair anim is skipped.
		_exit_bob_time += delta
		needs_redraw = true
	else:
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
	# safety net: if nothing is hovered anymore, no exit zone is hovered either
	# (covers teleports/room changes where a mouse_exited signal can be missed).
	if not hovering and is_exit_mode:
		clear_exit_mode()

func set_exit_mode(direction: int):
	# idempotent: GameManager re-asserts this on every hover-stack update; only a
	# genuine state/direction change restarts the bob.
	var dir: int = -1 if direction < 0 else 1
	if is_exit_mode and exit_direction == dir:
		return
	is_exit_mode = true
	exit_direction = dir
	_exit_bob_time = 0.0
	$Control.queue_redraw()

func clear_exit_mode():
	is_exit_mode = false
	$Control.queue_redraw()
