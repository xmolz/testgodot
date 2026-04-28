extends CanvasLayer
class_name ObjectZoomOverlay

signal zoom_view_closed

@export var background_texture: Texture2D
@export var default_verb_id: String = ""

@onready var close_button: Button = $RootContainer/CloseButton
@onready var zoom_background: TextureRect = $RootContainer/ZoomBackground

func _ready():
	# --- Set the Background Texture from the Inspector ---
	if zoom_background:
		if background_texture:
			zoom_background.texture = background_texture
		else:
			print_rich("[color=orange]ObjectZoomOverlay: No 'background_texture' has been assigned in the Inspector.[/color]")
	else:
		print_rich("[color=red]ObjectZoomOverlay: The 'ZoomBackground' node was not found under RootContainer![/color]")

	# --- Connect the Close Button ---
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

		# --- APPLY POLISHED STYLING ---
		var custom_font = preload("res://Fonts/VarelaRound-Regular.ttf")
		close_button.text = "Close"
		close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		close_button.add_theme_font_override("font", custom_font)
		close_button.add_theme_font_size_override("font_size", 24)

		var btn_normal = StyleBoxFlat.new()
		btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.85)
		btn_normal.corner_radius_top_left = 6
		btn_normal.corner_radius_top_right = 6
		btn_normal.corner_radius_bottom_left = 6
		btn_normal.corner_radius_bottom_right = 6
		btn_normal.content_margin_left = 25
		btn_normal.content_margin_right = 25
		btn_normal.content_margin_top = 10
		btn_normal.content_margin_bottom = 10
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

	# --- Inform the GameManager about the state change ---
	if GameManager and GameManager.has_method("enter_zoom_view_state"):
		GameManager.enter_zoom_view_state()

		# 1. Clear whatever verb/item got us into this view silently
		GameManager.cancel_current_action(false)

		# 2. If a default verb is assigned in the inspector, select it automatically
		if not default_verb_id.is_empty():
			GameManager.select_verb(default_verb_id)
			# Make it sticky so it doesn't unselect after one use
			GameManager.persisting_verb_id = default_verb_id
	else:
		print_rich("[color=orange]ObjectZoomOverlay: GameManager or enter_zoom_view_state() not found.[/color]")


# --- THIS IS THE MISSING FUNCTION ---
func _on_close_button_pressed():
	# When the button is pressed, we start the cleanup process.
	_cleanup_and_queue_free()


# --- Cleanup Functions ---
func _cleanup_and_queue_free():
	# Clear the sticky verb and the current action silently before returning to the world
	if GameManager:
		GameManager.persisting_verb_id = ""
		GameManager.cancel_current_action(false)

	# Inform the GameManager that we are returning to the main level.
	if GameManager and GameManager.has_method("exit_to_world_state"):
		GameManager.exit_to_world_state()

	# Disconnect the signal to be tidy.
	if close_button and close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.disconnect(_on_close_button_pressed)

	# Emit our own signal before we disappear.
	zoom_view_closed.emit()

	# Remove the overlay from the game.
	queue_free()
