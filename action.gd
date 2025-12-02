# res://interactions/Action.gd
class_name Action
extends Resource

# MODIFIED LINE: Changed -> void to -> bool
func execute(interactable_node: Interactable) -> bool:
	push_warning("An Action resource did not override the execute() method!")
	# MODIFIED LINE: Return true by default.
	return true
