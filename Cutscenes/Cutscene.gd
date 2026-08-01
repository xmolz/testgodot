class_name Cutscene
extends Node

# this signal allows the trigger
signal cutscene_finished

var _save_gate_released: bool = false

func _ready():
	# single init path: fires once per level registration for both
	# fresh runs and loads, after saved flags are applied (see step 1.6).
	Events.level_state_ready.connect(_on_level_state_ready)

# virtual. override in subclasses that mark an "in progress" level flag:
# if your flag is true on level init, the sequence was interrupted by a
# save/load — reconcile the world to your terminal state here.
# NOTE: If a subclass ever needs its own _ready, it must call super._ready().
func _on_level_state_ready() -> void:
	pass

# call this to start the sequence
func start_cutscene():
	print_rich("[color=Orchid]CutsceneSystem: Starting cutscene '%s'[/color]" % name)
	
	_save_gate_released = false
	if GameManager:
		GameManager.active_cutscene_count += 1
	
	# change gamestate to cutscene (this
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.CUTSCENE)
	else:
		push_error("Cutscene: GameManager not found!")

	# run the specific steps for this cutscene
	await _execution_steps()
	
	# finish up
	_finish_cutscene()

# call this from _execution_steps() at the moment player control returns,
# but ONLY in cutscenes that implement _on_level_state_ready fast-forwarding.
func release_save_gate():
	if _save_gate_released: return
	_save_gate_released = true
	if GameManager:
		GameManager.active_cutscene_count = max(0, GameManager.active_cutscene_count - 1)

# virtual function: override this in
func _execution_steps():
	# default behavior: wait one frame so it's not instant
	await get_tree().process_frame

func _finish_cutscene():
	print_rich("[color=Orchid]CutsceneSystem: Finishing cutscene '%s'[/color]" % name)
	
	# restore gamestate to play (this
	if GameManager:
		GameManager.change_game_state(GameManager.GameState.IN_GAME_PLAY)
	
	release_save_gate()
	cutscene_finished.emit()
