# res://interactions/Action.gd
class_name Action
extends Resource

# CHANGE: Removed "-> bool" and replaced with "-> Variant"
# This allows the function to handle both instant returns AND async "await" returns.
func execute(interactable_node: Interactable) -> Variant:
	push_warning("An Action resource did not override the execute() method!")
	# Return true by default.
	return true
