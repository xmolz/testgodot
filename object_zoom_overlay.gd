extends CanvasLayer
class_name ObjectZoomOverlay

signal zoom_view_closed

@export var background_texture: Texture2D

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
	else:
		print_rich("[color=red]ObjectZoomOverlay: The 'CloseButton' node was not found! The player may get stuck.[/color]")

	# --- Inform the GameManager about the state change ---
	if GameManager and GameManager.has_method("enter_zoom_view_state"):
		GameManager.enter_zoom_view_state()
	else:
		print_rich("[color=orange]ObjectZoomOverlay: GameManager or enter_zoom_view_state() not found.[/color]")


# --- THIS IS THE MISSING FUNCTION ---
func _on_close_button_pressed():
	# When the button is pressed, we start the cleanup process.
	_cleanup_and_queue_free()


# --- Cleanup Functions ---
func _cleanup_and_queue_free():
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
