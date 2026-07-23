# mainmenu.gd
extends CanvasLayer
# the gamemanager is listening for these specific signal
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

	_add_version_label()

func _on_new_game_button_pressed():
	# verify the click is working in the output log
	print("MainMenu: New Game Button Pressed")
	if SoundManager: SoundManager.play_sfx("start_game")
	new_game_requested.emit()

func _on_quit_button_pressed():
	print("MainMenu: Quit Button Pressed")
	quit_game_requested.emit()

func _on_settings_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var settings_scene = load("res://ui/settings_menu.tscn")
	if settings_scene:
		var instance = settings_scene.instantiate()
		get_tree().root.add_child(instance)

func _on_credits_button_pressed():
	if SoundManager: SoundManager.play_sfx("ui_click")
	var credits_scene = load("res://ui/credits_menu.tscn")
	if credits_scene:
		var instance = credits_scene.instantiate()
		get_tree().root.add_child(instance)

func _add_version_label():
	var version = str(ProjectSettings.get_setting("application/config/version", ""))
	if version.is_empty():
		return

	var version_label = Label.new()
	version_label.name = "VersionLabel"
	version_label.text = "v" + version
	version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version_label.modulate.a = 0.5

	version_label.add_theme_font_override("font", preload("res://Fonts/VarelaRound-Regular.ttf"))
	version_label.add_theme_font_size_override("font_size", 28 if OS.has_feature("mobile") else 16)

	add_child(version_label)
	version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
