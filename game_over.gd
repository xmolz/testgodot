extends CanvasLayer

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	animation_player.play("fade_in")

func _on_main_menu_button_pressed():
	if SoundManager and SoundManager.has_method("play_sfx"):
		SoundManager.play_sfx("ui_click", 1.5)

	# Swap back to Main Menu state
	GameManager.change_game_state(GameManager.GameState.MAIN_MENU)

	# Fade the black screen away smoothly so we can see the menu
	if is_instance_valid(GameManager.transition_layer) and GameManager.transition_layer.has_method("global_fade_from_black"):
		GameManager.transition_layer.global_fade_from_black(1.5)

	# Destroy this game over screen
	queue_free()
