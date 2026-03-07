# LevelStateManager.gd
extends Node
class_name LevelStateManager

signal level_flag_changed(flag_name: String, new_value: bool)

# All level flags stored in a single dictionary. No need to edit this script to add new flags —
# just call set_level_flag("my_new_flag", true) from anywhere.
var _flags: Dictionary = {}

# Default flag values for this level. Only needed for flags that start as true.
var _defaults: Dictionary = {
	"aida_in_main_room": true
}

# Set flag overrides here in the Inspector for testing. e.g. "mcbucket_zanopram_used": true
@export var debug_flag_overrides: Dictionary = {}


func _ready():
	for key in _defaults:
		_flags[key] = _defaults[key]
	for key in debug_flag_overrides:
		_flags[key] = debug_flag_overrides[key]
	print_rich("[color=LawnGreen]LevelStateManager for '%s' is ready.[/color]" % (get_parent().name if get_parent() else "UnnamedLevel"))


func print_initial_flags():
	for flag_name in _flags:
		print_rich("  [color=gray]Initial Flag '%s': %s[/color]" % [flag_name, _flags[flag_name]])


func set_level_flag(flag_name: String, value: bool):
	if _flags.get(flag_name, false) == value:
		return

	_flags[flag_name] = value
	print_rich("[color=LawnGreen]LevelStateManager ('%s'): Level Flag Set -> %s = %s[/color]" % [get_parent().name if get_parent() else "", flag_name, value])
	level_flag_changed.emit(flag_name, value)


func get_level_flag(flag_name: String) -> bool:
	return _flags.get(flag_name, false)
