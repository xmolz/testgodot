extends CanvasLayer
## Generic windowed close-up host (portraits, notes, small props). Same
## contract as keypad_panel.gd: the tree is never paused; OpenCloseupAction
## locks the player on the way in; _close() restores via exit_to_world_state().
## Click the Dim, press Back, or Esc to close. The content is any Control
## scene with a custom_minimum_size, handed over via content_scene before
## add_child.

signal panel_closed

const COLOR_BACK_BG := Color(0.16, 0.17, 0.19, 0.92)
const COLOR_BACK_BG_HOVER := Color(0.22, 0.23, 0.26, 0.95)
const COLOR_BACK_TEXT := Color(0.9, 0.9, 0.9, 1.0)

@export var content_scene: PackedScene
@export var dim_alpha: float = 0.55
@export var open_seconds: float = 0.18

var _is_closing := false

@onready var _dim: ColorRect = $Dim
@onready var _center: CenterContainer = $Center
@onready var _content_slot: MarginContainer = $Center/Stack/ContentSlot
@onready var _back_button: Button = $Center/Stack/BackButton


func _ready() -> void:
	_dim.color = Color(0.0, 0.0, 0.0, dim_alpha)
	if content_scene:
		_content_slot.add_child(content_scene.instantiate())
	else:
		push_warning("closeup_panel: no content_scene set.")
	_style_back_button(34 if OS.has_feature("mobile") else 30)
	_back_button.pressed.connect(_close)
	_dim.gui_input.connect(_on_dim_gui_input)
	_play_open_animation()


func _make_back_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _style_back_button(font_size: int) -> void:
	_back_button.text = "Back"
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.add_theme_font_size_override("font_size", font_size)
	_back_button.add_theme_stylebox_override("normal", _make_back_style(COLOR_BACK_BG))
	_back_button.add_theme_stylebox_override("hover", _make_back_style(COLOR_BACK_BG_HOVER))
	_back_button.add_theme_stylebox_override("pressed", _make_back_style(COLOR_BACK_BG_HOVER))
	_back_button.add_theme_color_override("font_color", COLOR_BACK_TEXT)
	_back_button.add_theme_color_override("font_hover_color", COLOR_BACK_TEXT.lightened(0.15))


func _play_open_animation() -> void:
	_dim.modulate.a = 0.0
	_center.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, open_seconds)
	tween.tween_property(_center, "modulate:a", 1.0, open_seconds)


func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()


func _close() -> void:
	if _is_closing:
		return
	_is_closing = true
	if GameManager:
		GameManager.exit_to_world_state()
	panel_closed.emit()
	queue_free()
