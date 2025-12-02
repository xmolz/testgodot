# res://interactions/actions/SetLevelFlagAction.gd
class_name SetLevelFlagAction
extends Action

## The name of the level flag to set. Must match a flag in the LevelStateManager.
@export var flag_name: String = ""
## The value to set the flag to.
@export var flag_value: bool = true


func execute(interactable_node: Interactable) -> bool:
	if flag_name.is_empty():
		push_warning("SetLevelFlagAction executed with an empty flag_name.")
		return true

	# Again, we use the interactable_node to emit the signal that the
	# GameManager is already listening for.
	interactable_node.request_set_level_flag.emit(flag_name, flag_value)
	return true
