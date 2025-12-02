# Boot.gd
extends Node

const LOGO_SPLASH_SCENE_PATH = "res://logo_splash.tscn"

func _ready():
	if not GameManager:
		print_rich("[color=red]Boot Error: GameManager not found! Cannot proceed.[/color]")
		return

	start_logo_splash()


func start_logo_splash():
	print_rich("[color=yellow]Boot: Starting logo splash...[/color]")

	if GameManager:
		GameManager.change_game_state(GameManager.GameState.LOGO_SPLASH)

	var logo_splash_packed_scene = load(LOGO_SPLASH_SCENE_PATH)
	if not logo_splash_packed_scene:
		print_rich("[color=red]Boot Error: Failed to load Logo Splash Scene at path: %s[/color]" % LOGO_SPLASH_SCENE_PATH)
		# If the logo fails, go straight to the menu
		if GameManager:
			GameManager.change_game_state(GameManager.GameState.MAIN_MENU)
		return

	var logo_splash_instance = logo_splash_packed_scene.instantiate()

	if not logo_splash_instance.has_signal("splash_finished"):
		print_rich("[color=red]Boot Error: LogoSplash scene does not have a 'splash_finished' signal. Cannot proceed automatically.[/color]")
		add_child(logo_splash_instance)
		return

	logo_splash_instance.splash_finished.connect(_on_logo_splash_finished, CONNECT_ONE_SHOT)
	add_child(logo_splash_instance)


func _on_logo_splash_finished():
	print_rich("[color=yellow]Boot: Logo splash finished. Transitioning to main menu...[/color]")
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.MAIN_MENU)
