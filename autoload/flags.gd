# Flags.gd (Autoload) — global (cross-level) flags + routing to the current level's flags.
extends Node

var game_flags: Dictionary = {}
var current_level_state_manager: LevelStateManager = null


# --- Global flags ---
func set_game_flag(flag_name: String, value: bool):
	if game_flags.get(flag_name, !value) == value:
		return
	game_flags[flag_name] = value


func get_game_flag(flag_name: String) -> bool:
	return game_flags.get(flag_name, false)


# --- Current level's flags ---
func register_level_state_manager(lsm: LevelStateManager):
	current_level_state_manager = lsm
	if is_instance_valid(lsm) and lsm.has_method("print_initial_flags"):
		lsm.print_initial_flags()


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
