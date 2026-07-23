class_name Cutscene
extends Node

# this signal allows the trigger
signal cutscene_finished

# call this to start the sequence
func start_cutscene():
	print_rich("[color=Orchid]CutsceneSystem: Starting cutscene '%s'[/color]" % name)
	
	# change gamestate to cutscene (this
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.CUTSCENE)
	else:
		push_error("Cutscene: GameManager not found!")

	# run the specific steps for this cutscene
	await _execution_steps()
	
	# finish up
	_finish_cutscene()

# virtual function: override this in
func _execution_steps():
	# default behavior: wait one frame so it's not instant
	await get_tree().process_frame

func _finish_cutscene():
	print_rich("[color=Orchid]CutsceneSystem: Finishing cutscene '%s'[/color]" % name)
	
	# restore gamestate to play (this
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.IN_GAME_PLAY)
	
	cutscene_finished.emit()
