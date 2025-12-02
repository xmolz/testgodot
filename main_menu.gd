# MainMenu.gd
extends Control

# Define the signals that this menu can send out.
# The GameManager will listen for these signals.
signal new_game_requested
signal quit_game_requested


# This function will be connected to the NewGameButton's 'pressed' signal.
func _on_new_game_button_pressed():
	# It doesn't start the game itself. It just announces the player's request.
	new_game_requested.emit()


# This function will be connected to the QuitButton's 'pressed' signal.
func _on_quit_button_pressed():
	# It doesn't quit the game itself. It just announces the request.
	quit_game_requested.emit()
