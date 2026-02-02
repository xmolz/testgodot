class_name Cutscene
extends Node

# This signal allows the Trigger to know when we are done (useful for chaining)
signal cutscene_finished

# Call this to start the sequence
func start_cutscene():
	print_rich("[color=Orchid]CutsceneSystem: Starting cutscene '%s'[/color]" % name)
	
	# 1. Change GameState to CUTSCENE (This hides UI and blocks Input via GM)
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.CUTSCENE)
	else:
		push_error("Cutscene: GameManager not found!")

	# 2. Run the specific steps for this cutscene
	await _execution_steps()
	
	# 3. Finish up
	_finish_cutscene()

# VIRTUAL FUNCTION: Override this in your specific cutscene script
func _execution_steps():
	# Default behavior: wait one frame so it's not instant
	await get_tree().process_frame

func _finish_cutscene():
	print_rich("[color=Orchid]CutsceneSystem: Finishing cutscene '%s'[/color]" % name)
	
	# 1. Restore GameState to PLAY (This restores UI and Input via GM)
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.IN_GAME_PLAY)
	
	cutscene_finished.emit()
