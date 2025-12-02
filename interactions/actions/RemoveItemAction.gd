# res://interactions/actions/RemoveItemAction.gd
class_name RemoveItemAction
extends Action

## The unique ID of the item to remove from the player's inventory.
@export var item_id_to_remove: String = ""


func execute(interactable_node: Interactable) -> bool:
	if item_id_to_remove.is_empty():
		push_warning("RemoveItemAction executed on '%s' with an empty item_id." % interactable_node.object_display_name)
		return true

	# We use the interactable_node to emit the existing signal that the
	# GameManager is already set up to listen for.
	interactable_node.request_remove_item_from_inventory.emit(item_id_to_remove)
	print_rich("[color=cyan]RemoveItemAction: Requested to remove item '%s' from inventory.[/color]" % item_id_to_remove)
	return true
