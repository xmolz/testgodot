# flags.gd (autoload) — global (cross-level)
extends Node

signal game_flag_changed(flag_name: String, value: bool)
signal level_state_manager_registered(lsm: LevelStateManager)

var game_flags: Dictionary = {}
var current_level_state_manager: LevelStateManager = null


# /////////////////// global flags
func set_game_flag(flag_name: String, value: bool):
	if game_flags.get(flag_name, !value) == value:
		return
	game_flags[flag_name] = value
	game_flag_changed.emit(flag_name, value)


func get_game_flag(flag_name: String) -> bool:
	return game_flags.get(flag_name, false)


# ////////////////[current level's flags]
func register_level_state_manager(lsm: LevelStateManager):
	current_level_state_manager = lsm
	if is_instance_valid(lsm) and lsm.has_method("print_initial_flags"):
		lsm.print_initial_flags()
	level_state_manager_registered.emit(lsm)


func set_level_flag(flag_name: String, value: bool):
	if is_instance_valid(current_level_state_manager):
		current_level_state_manager.set_level_flag(flag_name, value)


func get_level_flag(flag_name: String) -> bool:
	if is_instance_valid(current_level_state_manager):
		return current_level_state_manager.get_level_flag(flag_name)
	return false


func reset_run_state():
	game_flags.clear()
	current_level_state_manager = null
