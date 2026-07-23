extends CanvasLayer

@onready var zoom_in_panel = $ZoomInPanel
@onready var zoom_out_panel = $ZoomOutPanel
@onready var zoom_in_button = $ZoomInPanel/MarginContainer/ZoomInButton
@onready var zoom_out_button = $ZoomOutPanel/MarginContainer/ZoomOutButton
@onready var zoom_in_margin = $ZoomInPanel/MarginContainer
@onready var zoom_out_margin = $ZoomOutPanel/MarginContainer

var gameplay_ui_visible: bool = true
var interaction_state_world: bool = true

const HOVER_TINT := Color(0.2, 0.85, 1.0, 1.0)

var _zoom_in_style: StyleBoxFlat
var _zoom_out_style: StyleBoxFlat

func _ready():
	_apply_style()
	
	# buttons are visual-only; the whole
	zoom_in_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_out_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_in_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	zoom_out_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	zoom_in_panel.gui_input.connect(_on_panel_gui_input.bind(true))
	zoom_out_panel.gui_input.connect(_on_panel_gui_input.bind(false))
	zoom_in_panel.mouse_entered.connect(_on_panel_hover.bind(true, true))
	zoom_in_panel.mouse_exited.connect(_on_panel_hover.bind(true, false))
	zoom_out_panel.mouse_entered.connect(_on_panel_hover.bind(false, true))
	zoom_out_panel.mouse_exited.connect(_on_panel_hover.bind(false, false))
	
	Events.interaction_state_changed.connect(_on_interaction_state_changed)
	if GameManager:
		interaction_state_world = (GameManager.current_interaction_state == GameManager.InteractionState.WORLD)
	update_visibility()
	
	# defer camera connection until tree
	call_deferred("_setup_camera_connection")

func _apply_style():
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.5)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = Color.WHITE
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.corner_radius_bottom_right = 10

	_zoom_in_style = panel_style
	_zoom_out_style = panel_style.duplicate()
	zoom_in_panel.add_theme_stylebox_override("panel", _zoom_in_style)
	zoom_out_panel.add_theme_stylebox_override("panel", _zoom_out_style)

	# position panel
	if OS.has_feature("mobile"):
		zoom_out_panel.offset_left = 20
		zoom_out_panel.offset_top = 20
		zoom_out_panel.offset_right = 160
		zoom_out_panel.offset_bottom = 130

		zoom_in_panel.offset_left = 180
		zoom_in_panel.offset_top = 20
		zoom_in_panel.offset_right = 320
		zoom_in_panel.offset_bottom = 130

		for margin in [zoom_in_margin, zoom_out_margin]:
			margin.add_theme_constant_override("margin_top", 25)
			margin.add_theme_constant_override("margin_bottom", 25)
			margin.add_theme_constant_override("margin_left", 25)
			margin.add_theme_constant_override("margin_right", 25)
	else:
		zoom_out_panel.offset_left = 20
		zoom_out_panel.offset_top = 20
		zoom_out_panel.offset_right = 100
		zoom_out_panel.offset_bottom = 100

		zoom_in_panel.offset_left = 110
		zoom_in_panel.offset_top = 20
		zoom_in_panel.offset_right = 190
		zoom_in_panel.offset_bottom = 100

func _on_panel_gui_input(event: InputEvent, is_zoom_in: bool):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var btn = zoom_in_button if is_zoom_in else zoom_out_button
		if btn.disabled:
			return
		if OS.has_feature("mobile"):
			_flash_press(btn)
		if is_zoom_in:
			_on_zoom_in_pressed()
		else:
			_on_zoom_out_pressed()

func _on_panel_hover(is_zoom_in: bool, entered: bool):
	var btn = zoom_in_button if is_zoom_in else zoom_out_button
	if btn.disabled:
		return
	btn.modulate = HOVER_TINT if entered else Color.WHITE
	var style = _zoom_in_style if is_zoom_in else _zoom_out_style
	if style:
		style.border_color = HOVER_TINT if entered else Color.WHITE

func _flash_press(btn: TextureButton):
	btn.modulate = HOVER_TINT
	var tw = create_tween()
	tw.tween_property(btn, "modulate", Color.WHITE, 0.15)

func _setup_camera_connection():
	var camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera) and camera.has_signal("zoom_changed"):
		camera.zoom_changed.connect(_update_states)
	_update_states()

func _update_states():
	var camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera):
		var can_in = camera.can_zoom_in() if camera.has_method("can_zoom_in") else false
		var can_out = camera.can_zoom_out() if camera.has_method("can_zoom_out") else false

		zoom_in_button.disabled = not can_in
		zoom_out_button.disabled = not can_out

		zoom_in_panel.self_modulate.a = 1.0 if can_in else 0.4
		zoom_out_panel.self_modulate.a = 1.0 if can_out else 0.4
	else:
		zoom_in_button.disabled = true
		zoom_out_button.disabled = true
		zoom_in_panel.self_modulate.a = 0.4
		zoom_out_panel.self_modulate.a = 0.4

	if zoom_in_button.disabled:
		zoom_in_button.modulate = Color.WHITE
		if _zoom_in_style: _zoom_in_style.border_color = Color.WHITE
	if zoom_out_button.disabled:
		zoom_out_button.modulate = Color.WHITE
		if _zoom_out_style: _zoom_out_style.border_color = Color.WHITE

func _on_zoom_in_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera) and camera.has_method("zoom_in"):
		camera.zoom_in()

func _on_zoom_out_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera) and camera.has_method("zoom_out"):
		camera.zoom_out()

func set_gameplay_ui_visible(show: bool):
	gameplay_ui_visible = show
	update_visibility()

func update_visibility():
	visible = gameplay_ui_visible and interaction_state_world

func _on_interaction_state_changed(new_state: int):
	interaction_state_world = (new_state == GameManager.InteractionState.WORLD)
	update_visibility()
