extends CanvasLayer
class_name ObjectZoomOverlay

signal zoom_view_closed

@export var background_texture: Texture2D
@export var default_verb_id: String = ""

# hud configuration for this zoom
@export var show_verb_panel: bool = true
@export var show_inventory: bool = true
# if non-empty, only these verb
@export var allowed_verb_ids: Array[String] = []

var _saved_scene_verb_ids: Array[String] = []
var _verbs_restricted: bool = false

@onready var close_button: Button = $RootContainer/CloseButton
@onready var zoom_background: TextureRect = $RootContainer/ZoomBackground

func _ready():
	# -------------------[set the background texture from the inspector]
	if zoom_background:
		if background_texture:
			zoom_background.texture = background_texture
		else:
			print_rich("[color=orange]ObjectZoomOverlay: No 'background_texture' has been assigned in the Inspector.[/color]")
	else:
		print_rich("[color=red]ObjectZoomOverlay: The 'ZoomBackground' node was not found under RootContainer![/color]")

	# **********************[connect the close button]
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

		# ----------[apply polished styling]
		var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")
		close_button.text = "Close"
		close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		close_button.add_theme_font_override("font", custom_font)
		close_button.add_theme_font_size_override("font_size", 46 if OS.has_feature("mobile") else 32)

		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
		btn_normal.corner_radius_top_left = 6
		btn_normal.corner_radius_top_right = 6
		btn_normal.corner_radius_bottom_left = 6
		btn_normal.corner_radius_bottom_right = 6
		btn_normal.content_margin_left = 50 if OS.has_feature("mobile") else 35
		btn_normal.content_margin_right = 50 if OS.has_feature("mobile") else 35
		btn_normal.content_margin_top = 25 if OS.has_feature("mobile") else 15
		btn_normal.content_margin_bottom = 25 if OS.has_feature("mobile") else 15

		close_button.reset_size()
		if OS.has_feature("mobile"):
			close_button.position = Vector2(40, 40)
		btn_normal.border_width_left = 2
		btn_normal.border_width_top = 2
		btn_normal.border_width_right = 2
		btn_normal.border_width_bottom = 2
		btn_normal.border_color = Color(1.0, 1.0, 1.0, 0.0)

		var btn_hover = btn_normal.duplicate()
		btn_hover.bg_color = Color(0.1, 0.25, 0.3, 0.9)
		btn_hover.border_color = Color(0.2, 0.85, 1.0, 0.8)

		close_button.add_theme_stylebox_override("normal", btn_normal)
		close_button.add_theme_stylebox_override("hover", btn_hover)
		close_button.add_theme_stylebox_override("focus", btn_hover)
		close_button.add_theme_stylebox_override("pressed", btn_hover)

		close_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
		close_button.add_theme_color_override("font_hover_color", Color.WHITE)
		close_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	else:
		print_rich("[color=red]ObjectZoomOverlay: The 'CloseButton' node was not found! The player may get stuck.[/color]")

	# ////////// inform the gamemanager about the state change
	if GameManager and GameManager.has_method("enter_zoom_view_state"):
		GameManager.enter_zoom_view_state()

		# clear whatever verb/item got us into this view silently
		GameManager.cancel_current_action(false)

		# restrict selectable verbs for the
		if not allowed_verb_ids.is_empty():
			_saved_scene_verb_ids = Verbs.active_scene_verb_ids.duplicate()
			_verbs_restricted = true
			Verbs.set_active_scene_verbs(allowed_verb_ids)

		# tell game_ui.gd which hud pieces this zoom wants.
		Events.zoom_hud_config_requested.emit(show_verb_panel, show_inventory)

		# if a default verb is
		if not default_verb_id.is_empty():
			GameManager.select_verb(default_verb_id)
			# make it sticky so it doesn't unselect after one use
			GameManager.persisting_verb_id = default_verb_id
	else:
		print_rich("[color=orange]ObjectZoomOverlay: GameManager or enter_zoom_view_state() not found.[/color]")


# ///////////(this is the missing function)
func _on_close_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	# when the button is pressed,
	_cleanup_and_queue_free()


# /////////////////// cleanup functions
func _cleanup_and_queue_free():
	if _verbs_restricted:
		_verbs_restricted = false
		Verbs.set_active_scene_verbs(_saved_scene_verb_ids)

	# clear the sticky verb and
	if GameManager:
		GameManager.persisting_verb_id = ""
		GameManager.cancel_current_action(false)

	# inform the gamemanager that we
	if GameManager and GameManager.has_method("exit_to_world_state"):
		GameManager.exit_to_world_state()

	# disconnect the signal to be tidy.
	if close_button and close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.disconnect(_on_close_button_pressed)

	# emit our own signal before we disappear.
	zoom_view_closed.emit()

	# remove the overlay from the game.
	queue_free()
