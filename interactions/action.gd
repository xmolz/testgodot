# res://interactions/action.gd
class_name Action
extends Resource

# change: removed "-> bool" and
# this allows the function to
func execute(interactable_node: Interactable) -> Variant:
	push_warning("An Action resource did not override the execute() method!")
	# return true by default.
	return true
