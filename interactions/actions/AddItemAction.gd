# res://interactions/actions/AddItemAction.gd
class_name AddItemAction
extends Action

@export var item_id_to_add: String = ""


# CHANGE THIS LINE: from "-> void" to "-> bool"
func execute(interactable_node: Interactable) -> bool:
	if item_id_to_add.is_empty():
		push_warning("AddItemAction executed on '%s' with an empty item_id." % interactable_node.object_display_name)
		return true # Also return true here for consistency

	interactable_node.request_add_item_to_inventory.emit(item_id_to_add)
	print_rich("[color=cyan]AddItemAction: Requested to add item '%s' to inventory.[/color]" % item_id_to_add)

	# This line is now valid because the function is declared to return a bool.
	return true
