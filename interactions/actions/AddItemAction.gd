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

	# --- NEW LOGIC: Automatically set the state flag so the item doesn't respawn ---
	if not interactable_node.state_flag_id.is_empty():
		if GameManager:
			GameManager.set_current_level_flag(interactable_node.state_flag_id, true)
			print_rich("[color=green]AddItemAction: Auto-set level flag '%s' to true.[/color]" % interactable_node.state_flag_id)

	return true
