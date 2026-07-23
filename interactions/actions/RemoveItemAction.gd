# res://interactions/actions/removeitemaction.gd
class_name RemoveItemAction
extends Action

# the unique id of the
@export var item_id_to_remove: String = ""


func execute(interactable_node: Interactable) -> bool:
	if item_id_to_remove.is_empty():
		push_warning("RemoveItemAction executed on '%s' with an empty item_id." % interactable_node.object_display_name)
		return true

	# we use the interactable_node to
	# gamemanager is already set up to listen for.
	Inventory.remove_item(item_id_to_remove)
	print_rich("[color=cyan]RemoveItemAction: Requested to remove item '%s' from inventory.[/color]" % item_id_to_remove)
	return true
