# MainMenu.gd
extends CanvasLayer
# The GameManager is listening for these specific signals
signal new_game_requested
signal quit_game_requested

func _on_new_game_button_pressed():
	# Verify the click is working in the Output log
	print("MainMenu: New Game Button Pressed")
	if SoundManager: SoundManager.play_sfx("start_game")
	new_game_requested.emit()

func _on_quit_button_pressed():
	print("MainMenu: Quit Button Pressed")
	quit_game_requested.emit()

func _on_settings_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var settings_scene = load("res://settings_menu.tscn")
	if settings_scene:
		var instance = settings_scene.instantiate()
		get_tree().root.add_child(instance)

func _on_credits_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var credits_scene = load("res://credits_menu.tscn")
	if credits_scene:
		var instance = credits_scene.instantiate()
		get_tree().root.add_child(instance)
