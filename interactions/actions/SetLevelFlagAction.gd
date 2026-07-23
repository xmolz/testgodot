# res://interactions/actions/setlevelflagaction.gd
class_name SetLevelFlagAction
extends Action

@export var flag_name: String = ""
@export var flag_value: bool = true

func execute(_interactable_node: Interactable) -> Variant:
	if flag_name == "":
		push_warning("SetLevelFlagAction: No flag_name specified.")
		return true

	if GameManager:
		# this calls the function you
		# which routes it to the current levelstatemanager
		Flags.set_level_flag(flag_name, flag_value)
		print("Action: Set Level Flag '%s' to %s" % [flag_name, str(flag_value)])
	
	return true
