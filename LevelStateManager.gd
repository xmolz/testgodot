# LevelStateManager.gd
extends Node
class_name LevelStateManager

# --- EXPORTED LEVEL-SPECIFIC FLAGS ---
# Add flags relevant to THIS level here.
# For our test:
@export var rusty_key_picked_up: bool = false
@export var key_used_on_burger: bool = false
@export var zanopram_taken: bool = false
@export var cannathink_taken: bool = false
@export var invigirol_taken: bool = false
@export var has_spoken_to_aida: bool = false
@export var aida_explanation_shown: bool = false
@export var insurance_button_unlocked: bool = false
@export var mcbucket_cannathink_used: bool = false
@export var memory_box_unlocked: bool = false
@export var mcbucket_invigirol_used: bool = false
@export var mcbucket_zanopram_used: bool = false
@export var toilet_clogged:bool = false
@export var aida_in_main_room:bool = false
@export var toilet_has_paper: bool = false # Stage 1: Paper dropped


# Example of other potential flags for a level:
# @export var generator_online: bool = false
# @export var npc_met_for_quest: bool = false
# @export var secret_door_unlocked: bool = false

func _ready():
	print_rich("[color=LawnGreen]LevelStateManager for '%s' is ready.[/color]" % get_parent().name if get_parent() else "UnnamedLevel")
	# You could print initial flag states here for debugging if needed
	# print_initial_flags()

func print_initial_flags():
	var properties = get_property_list()
	for p in properties:
		if p.usage & PROPERTY_USAGE_STORAGE: # Check if it's a stored property (like exported ones)
			if get(p.name) is bool: # Only care about boolean flags for this example
				print_rich("  [color=gray]Initial Flag '%s': %s[/color]" % [p.name, get(p.name)])


# Generic function to set any exported boolean flag by its string name
func set_level_flag(flag_name: String, value: bool):
	if not has_meta(flag_name) and get(flag_name) == null: # Check if property exists
		# A more robust check might involve iterating get_property_list()
		# to ensure 'flag_name' is a valid exported bool property.
		# For now, we rely on 'get(flag_name)' not being null if it's an exported var.
		var property_exists = false
		for prop_info in get_property_list():
			if prop_info.name == flag_name and prop_info.type == TYPE_BOOL:
				property_exists = true
				break

		if not property_exists:
			print_rich("[color=red]LevelStateManager ('%s'): Attempted to set non-existent or non-boolean exported flag: '%s'[/color]" % [get_parent().name if get_parent() else "", flag_name])
			return

	if get(flag_name) == value:
		# print_rich("[color=gray]LevelStateManager ('%s'): Flag '%s' already set to %s. No change.[/color]" % [get_parent().name if get_parent() else "", flag_name, value])
		return # No change

	set(flag_name, value) # Use set() to modify exported vars by string name
	print_rich("[color=LawnGreen]LevelStateManager ('%s'): Level Flag Set -> %s = %s[/color]" % [get_parent().name if get_parent() else "", flag_name, value])

	# You could add logic here to check for level completion or trigger other events
	# based on this flag change. For example:
	# if flag_name == "rusty_key_picked_up" and value == true:
	#     check_if_all_keys_collected()


# Generic function to get any exported boolean flag by its string name
func get_level_flag(flag_name: String) -> bool:
	var property_exists = false
	for prop_info in get_property_list():
		if prop_info.name == flag_name and prop_info.type == TYPE_BOOL:
			property_exists = true
			break

	if not property_exists:
		# print_rich("[color=orange]LevelStateManager ('%s'): Attempted to get non-existent or non-boolean exported flag: '%s'. Returning false.[/color]" % [get_parent().name if get_parent() else "", flag_name])
		return false

	var flag_value = get(flag_name)
	if flag_value is bool:
		return flag_value

	# print_rich("[color=orange]LevelStateManager ('%s'): Flag '%s' is not a boolean. Returning false.[/color]" % [get_parent().name if get_parent() else "", flag_name])
	return false # Should not happen if property_exists check is good
