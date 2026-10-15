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


# /////////////////// global counters (step 2.233)
# whole numbers kept in game_flags under a "counter_" prefix, so the existing save/load and
# reset_run_state cover them. they never go through get_game_flag / game_flag_changed.
const COUNTER_PREFIX := "counter_"

func add_game_counter(counter_name: String, delta: float) -> float:
	var key := COUNTER_PREFIX + counter_name
	var value: float = float(game_flags.get(key, 0.0)) + delta
	game_flags[key] = value
	print_rich("[color=yellow]Flags: %s %+.1f -> %.1f[/color]" % [counter_name, delta, value])
	return value


func get_game_counter(counter_name: String) -> float:
	return float(game_flags.get(COUNTER_PREFIX + counter_name, 0.0))


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
