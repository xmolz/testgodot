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

@export_group("Debug Flag Toggles")
@export var override_has_spoken_to_aida: bool = false
@export var override_aida_explanation_shown: bool = false
@export var override_insurance_button_unlocked: bool = false
@export var override_has_tried_memory_box: bool = false
@export var override_mcbucket_interruption_happened: bool = false
@export var override_mcbucket_has_screamed_at_player: bool = false
@export var override_mcbucket_zanopram_used: bool = false
@export var override_mcbucket_cannathink_used: bool = false
@export var override_mcbucket_invigirol_used: bool = false
@export var override_toilet_has_paper: bool = false
@export var override_toilet_clogged: bool = false
@export var override_give_techpass: bool = false


func _ready():
	for key in _defaults:
		_flags[key] = _defaults[key]

	# Apply individual debug toggles (only if true, so unchecked = no effect)
	var _toggles := {
		"has_spoken_to_aida": override_has_spoken_to_aida,
		"aida_explanation_shown": override_aida_explanation_shown,
		"insurance_button_unlocked": override_insurance_button_unlocked,
		"has_tried_memory_box": override_has_tried_memory_box,
		"mcbucket_interruption_happened": override_mcbucket_interruption_happened,
		"mcbucket_has_screamed_at_player": override_mcbucket_has_screamed_at_player,
		"mcbucket_zanopram_used": override_mcbucket_zanopram_used,
		"mcbucket_cannathink_used": override_mcbucket_cannathink_used,
		"mcbucket_invigirol_used": override_mcbucket_invigirol_used,
		"toilet_has_paper": override_toilet_has_paper,
		"toilet_clogged": override_toilet_clogged,
	}
	for flag_name in _toggles:
		if _toggles[flag_name]:
			_flags[flag_name] = true

	# Debug: give techpass item directly
	if override_give_techpass and GameManager:
		GameManager.add_item_to_inventory("techpass")

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
