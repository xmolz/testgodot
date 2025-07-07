# Boot.gd
extends Node

# --- CONFIGURE THESE PATHS ---
# Paths to your main scenes and assets.
const LOGO_SPLASH_SCENE_PATH = "res://logo_splash.tscn" # Path to your new logo splash scene
const INTRO_OVERLAY_SCENE_PATH = "res://CharacterConversationOverlay.tscn"
const MAIN_GAME_SCENE_PATH = "res://main.tscn" #

# Configuration for your specific intro overlay
const INTRO_DIALOGUE_FILE_PATH = "res://dialogue/npcs/faye.dialogue" # Or your intro dialogue
const INTRO_BACKGROUND_ANIMATIONS_PATH = "res://conversation_backgrounds.tres"
const INTRO_INITIAL_ANIMATION_NAME = "float_loop"
# --- END OF CONFIGURATION ---


func _ready():
	# This function runs once when the game starts.

	# 1. Load the main game scene but keep it hidden.
	var main_game_packed_scene = load(MAIN_GAME_SCENE_PATH)
	if not main_game_packed_scene:
		print_rich("[color=red]Boot Error: Failed to load Main Game Scene at path: %s[/color]" % MAIN_GAME_SCENE_PATH)
		return

	var main_game_scene = main_game_packed_scene.instantiate()
	main_game_scene.visible = false
	add_child(main_game_scene)

	# 2. Give the GameManager a direct reference to the main game scene instance.
	if GameManager:
		GameManager.main_game_scene_instance = main_game_scene
	else:
		print_rich("[color=red]Boot Error: GameManager not found! Cannot proceed.[/color]")
		return

	# 3. Start the entire sequence, beginning with the logo splash.
	start_logo_splash()


func start_logo_splash():
	print_rich("[color=yellow]Boot: Starting logo splash...[/color]")

	# Tell the GameManager the new state
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.LOGO_SPLASH)

	# Load and instance the logo splash scene
	var logo_splash_packed_scene = load(LOGO_SPLASH_SCENE_PATH)
	if not logo_splash_packed_scene:
		print_rich("[color=red]Boot Error: Failed to load Logo Splash Scene at path: %s[/color]" % LOGO_SPLASH_SCENE_PATH)
		# If the splash fails, maybe we should just skip to the intro?
		start_intro()
		return

	var logo_splash_instance = logo_splash_packed_scene.instantiate()

	# We need to know when the splash is finished.
	# This requires your LogoSplash scene to have a signal called "splash_finished".
	if not logo_splash_instance.has_signal("splash_finished"):
		print_rich("[color=red]Boot Error: LogoSplash scene does not have a 'splash_finished' signal. Cannot proceed automatically.[/color]")
		# Clean up and just show the broken splash screen.
		add_child(logo_splash_instance)
		return

	logo_splash_instance.splash_finished.connect(_on_logo_splash_finished, CONNECT_ONE_SHOT)

	add_child(logo_splash_instance)


func _on_logo_splash_finished():
	print_rich("[color=yellow]Boot: Logo splash finished. Starting intro sequence...[/color]")
	# Now we call the function to start the next part of the sequence.
	start_intro()


func start_intro():
	print_rich("[color=yellow]Boot: Starting intro sequence...[/color]")

	# Tell the GameManager the new state
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.INTRO_CONVERSATION)

	var intro_overlay_packed_scene = load(INTRO_OVERLAY_SCENE_PATH)
	if not intro_overlay_packed_scene:
		print_rich("[color=red]Boot Error: Failed to load Intro Overlay Scene at path: %s[/color]" % INTRO_OVERLAY_SCENE_PATH)
		return

	var intro_overlay = intro_overlay_packed_scene.instantiate()

	# Configure its exported variables from code.
	intro_overlay.conversation_dialogue_file = load(INTRO_DIALOGUE_FILE_PATH)
	intro_overlay.background_animations = load(INTRO_BACKGROUND_ANIMATIONS_PATH)
	intro_overlay.initial_animation_name = INTRO_INITIAL_ANIMATION_NAME

	# Connect to its 'conversation_finished' signal.
	intro_overlay.conversation_finished.connect(_on_intro_conversation_finished, CONNECT_ONE_SHOT)

	# Add it to the scene tree so it becomes visible and starts running.
	add_child(intro_overlay)


func _on_intro_conversation_finished(_dialogue_resource):
	print_rich("[color=yellow]Boot: Intro conversation finished. Transitioning to main game...[/color]")

	if GameManager:
		GameManager.change_game_state(GameManager.GameState.IN_GAME_PLAY)
