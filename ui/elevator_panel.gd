extends CanvasLayer

signal panel_closed

const BALLOON_SCENE_PATH := "res://conversation/conversationballoon.tscn"
const EXAMINABLES_DIALOGUE_PATH := "res://dialogue/examinables.dialogue"
const CHECKPOINT_RESTRICTED := "elevator_floor_restricted"
const CHECKPOINT_CURRENT := "elevator_floor_current"

## Floor directory (US numbering: street level = 1F). Edit freely.
## behavior values: restricted (Fiona declines) or transition (shutter door
## transition plays; no teleport yet). The floor whose id equals
## current_floor_id always plays the already-here line instead.
const FLOORS: Array[Dictionary] = [
	{"id": "R", "label": "R     Rooftop", "behavior": "restricted"},
	{"id": "5F", "label": "5F    Gym, Leisure Room", "behavior": "restricted"},
	{"id": "4F", "label": "4F    Faculty Offices", "behavior": "transition"},
	{"id": "3F", "label": "3F    Classrooms, Grad Commons", "behavior": "transition"},
	{"id": "2F", "label": "2F    Library, Science Labs", "behavior": "restricted"},
	{"id": "1F", "label": "1F    Cafeteria, Auditorium", "behavior": "restricted"},
	{"id": "B", "label": "B     Parking", "behavior": "restricted"},
]

const COLOR_TEXT := Color(0.933, 0.933, 0.933, 1.0)
const COLOR_ACCENT := Color(0.2, 0.85, 1.0, 1.0)
const COLOR_ACCENT_BRIGHT := Color(0.4, 0.95, 1.0, 1.0)
const COLOR_ACCENT_SOFT := Color(0.2, 0.85, 1.0, 0.35)
const COLOR_PANEL_BG := Color(0.055, 0.075, 0.105, 0.97)
const COLOR_ROW_BG := Color(0.15, 0.15, 0.15, 0.9)
const COLOR_ROW_HOVER_BG := Color(0.1, 0.25, 0.3, 0.95)

const GUTTER_WIDTH := 64.0
const ARROW_BASE_X := 12.0
const ARROW_BOUNCE_DISTANCE := 14.0
const ARROW_BOUNCE_TIME := 0.45

@export var current_floor_id: String = "2F"
@export var title_text: String = "What floor do you want to go to?"

var _is_resolving := false

@onready var _dim: ColorRect = $Dim
@onready var _center: CenterContainer = $Center
@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _floor_list: VBoxContainer = $Center/Panel/Margin/VBox/FloorList
@onready var _close_button: Button = $Center/Panel/Margin/VBox/CloseButton

func _ready() -> void:
	var title_size := 44
	var row_size := 34
	if OS.has_feature("mobile"):
		title_size = 52
		row_size = 40

	_style_panel()

	_title.text = title_text
	_title.add_theme_font_size_override("font_size", title_size)
	_title.add_theme_color_override("font_color", COLOR_TEXT)

	_setup_button(_close_button, row_size, false)
	_close_button.pressed.connect(_close)

	_dim.gui_input.connect(_on_dim_gui_input)

	for floor_data in FLOORS:
		var is_current: bool = floor_data["id"] == current_floor_id

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var gutter := Control.new()
		gutter.custom_minimum_size = Vector2(GUTTER_WIDTH, 0)
		gutter.size_flags_vertical = Control.SIZE_FILL
		gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(gutter)

		var button := Button.new()
		button.text = floor_data["label"]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_setup_button(button, row_size, is_current)
		button.pressed.connect(_on_floor_pressed.bind(floor_data["id"]))
		row.add_child(button)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(GUTTER_WIDTH, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spacer)

		_floor_list.add_child(row)

		if is_current:
			_attach_current_floor_arrow(gutter, button)

	_play_open_animation()

func _attach_current_floor_arrow(gutter: Control, row_button: Button) -> void:
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(0, -15), Vector2(26, 0), Vector2(0, 15)])
	arrow.color = COLOR_ACCENT_BRIGHT
	arrow.antialiased = true
	arrow.position = Vector2(ARROW_BASE_X, 0.0)
	gutter.add_child(arrow)

	var recenter := func() -> void:
		arrow.position.y = row_button.size.y / 2.0
	row_button.resized.connect(recenter)
	recenter.call_deferred()

	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(arrow, "position:x", ARROW_BASE_X + ARROW_BOUNCE_DISTANCE, ARROW_BOUNCE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(arrow, "position:x", ARROW_BASE_X, ARROW_BOUNCE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _style_panel() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_color = COLOR_ACCENT_SOFT
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	_panel.add_theme_stylebox_override("panel", panel_style)

func _make_row_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(12)
	style.content_margin_left = 22.0
	style.content_margin_right = 22.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _setup_button(button: Button, font_size: int, is_current: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)

	var normal_border := COLOR_ACCENT_SOFT if is_current else Color(1.0, 1.0, 1.0, 0.0)
	var normal_border_width := 2 if is_current else 0
	button.add_theme_stylebox_override("normal", _make_row_style(COLOR_ROW_BG, normal_border, normal_border_width))
	button.add_theme_stylebox_override("hover", _make_row_style(COLOR_ROW_HOVER_BG, Color(0.2, 0.85, 1.0, 0.8), 2))
	button.add_theme_stylebox_override("pressed", _make_row_style(COLOR_ROW_HOVER_BG.lightened(0.08), COLOR_ACCENT, 2))

	button.add_theme_color_override("font_color", COLOR_ACCENT if is_current else COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_ACCENT_BRIGHT)
	button.add_theme_color_override("font_pressed_color", COLOR_ACCENT_BRIGHT)

func _play_open_animation() -> void:
	_dim.modulate.a = 0.0
	_center.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, 0.18)
	tween.tween_property(_center, "modulate:a", 1.0, 0.18)

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close()

func _behavior_for(floor_id: String) -> String:
	for floor_data in FLOORS:
		if floor_data["id"] == floor_id:
			return floor_data.get("behavior", "restricted")
	return "restricted"

func _on_floor_pressed(floor_id: String) -> void:
	if _is_resolving:
		return
	if floor_id == current_floor_id:
		_close_with_line(CHECKPOINT_CURRENT)
	elif _behavior_for(floor_id) == "transition":
		_close_with_transition()
	else:
		_close_with_line(CHECKPOINT_RESTRICTED)

func _close_with_line(checkpoint: String) -> void:
	_is_resolving = true
	get_tree().paused = false
	if GameManager:
		GameManager.exit_to_world_state()
		if is_instance_valid(GameManager.player_node) and GameManager.player_node.has_method("set_can_move"):
			GameManager.player_node.set_can_move(false)
		DialogueManager.dialogue_ended.connect(GameManager.restore_world_after_object_dialogue, CONNECT_ONE_SHOT)
	DialogueManager.show_dialogue_balloon_scene(BALLOON_SCENE_PATH, load(EXAMINABLES_DIALOGUE_PATH), checkpoint)
	panel_closed.emit()
	queue_free()

func _close_with_transition() -> void:
	_is_resolving = true
	get_tree().paused = false
	_dim.visible = false
	_center.visible = false
	if GameManager and is_instance_valid(GameManager.transition_layer) and GameManager.transition_layer.has_method("play_transition_sequence"):
		await GameManager.transition_layer.play_transition_sequence()
	else:
		push_warning("ElevatorPanel: transition_layer unavailable; skipped door transition.")
	if GameManager:
		GameManager.exit_to_world_state()
	panel_closed.emit()
	queue_free()

func _close() -> void:
	if _is_resolving:
		return
	_is_resolving = true
	get_tree().paused = false
	if GameManager:
		GameManager.exit_to_world_state()
	panel_closed.emit()
	queue_free()
