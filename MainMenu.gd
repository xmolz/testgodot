# MainMenu.gd
extends CanvasLayer
# The GameManager is listening for these specific signals
signal new_game_requested
signal quit_game_requested

func _on_new_game_button_pressed():
	# Verify the click is working in the Output log
	print("MainMenu: New Game Button Pressed") 
	new_game_requested.emit()

func _on_quit_button_pressed():
	print("MainMenu: Quit Button Pressed")
	quit_game_requested.emit()
