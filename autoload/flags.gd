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
	# step 2.296: while layla is locked distant (two hurts in one chapter), nothing raises her closeness.
	if counter_name == "layla_closeness" and delta > 0.0 and game_flags.get("layla_locked_distant", false) == true:
		print_rich("[color=yellow]Flags: layla_closeness %+.1f ignored (locked distant)[/color]" % delta)
		return float(game_flags.get(key, 0.0))
	var value: float = float(game_flags.get(key, 0.0)) + delta
	game_flags[key] = value
	print_rich("[color=yellow]Flags: %s %+.1f -> %.1f[/color]" % [counter_name, delta, value])
	return value


## step 2.296: reprimanding layla and nearly telling julian about her, in one chapter, locks her distant
## for the rest of it: closeness drops to at most -1 and can't rise again. the car ride clears the flag.
func lock_layla_distant() -> void:
	set_game_flag("layla_locked_distant", true)
	var current: float = get_game_counter("layla_closeness")
	if current > -1.0:
		add_game_counter("layla_closeness", -1.0 - current)


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
