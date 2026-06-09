# MainMenu.gd
extends CanvasLayer
# The GameManager is listening for these specific signals
signal new_game_requested
signal quit_game_requested

@onready var button_block = $Content/ButtonBlock
@onready var start_btn = $Content/ButtonBlock/StartButton
@onready var settings_btn = $Content/ButtonBlock/SettingsButton
@onready var credits_btn = $Content/ButtonBlock/CreditsButton
@onready var quit_btn = $Content/ButtonBlock/QuitButton

func _ready():
	if OS.has_feature("mobile"):
		button_block.add_theme_constant_override("separation", 40)

		var mobile_font_size = 54
		start_btn.add_theme_font_size_override("font_size", mobile_font_size)
		settings_btn.add_theme_font_size_override("font_size", mobile_font_size)
		credits_btn.add_theme_font_size_override("font_size", mobile_font_size)
		quit_btn.add_theme_font_size_override("font_size", mobile_font_size)

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
