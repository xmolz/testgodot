# res://interactions/actions/additemaction.gd
class_name AddItemAction
extends Action

@export var item_id_to_add: String = ""

# optional: if set, this dialogue
# (non-stackable) item is already in
# leave both unset to keep the legacy silent behavior.
@export var already_have_dialogue: DialogueResource
@export var already_have_checkpoint: String = ""

const BALLOON_SCENE_PATH = "res://conversation/conversationballoon.tscn"


# return type is variant so
func execute(interactable_node: Interactable) -> Variant:
	if item_id_to_add.is_empty():
		push_warning("AddItemAction executed on '%s' with an empty item_id." % interactable_node.object_display_name)
		return true

	# ************************[already-in-inventory feedback (non-stackable items only)]
	var item_data = Inventory.get_item_data_by_id(item_id_to_add)
	if item_data and not item_data.is_stackable and Inventory.has_item(item_id_to_add):
		if already_have_dialogue and not already_have_checkpoint.is_empty():
			if not already_have_dialogue.titles.has(already_have_checkpoint):
				push_warning("AddItemAction: checkpoint '%s' not found in dialogue resource. Skipping line." % already_have_checkpoint)
				return true
			DialogueManager.show_dialogue_balloon_scene(BALLOON_SCENE_PATH, already_have_dialogue, already_have_checkpoint)
			await DialogueManager.dialogue_ended
		# either way: skip the add,
		return true

	Inventory.add_item(item_id_to_add)
	print_rich("[color=cyan]AddItemAction: Requested to add item '%s' to inventory.[/color]" % item_id_to_add)

	# ----------------[automatically set the state flag so the item doesn't respawn]
	if not interactable_node.state_flag_id.is_empty():
		if GameManager:
			Flags.set_level_flag(interactable_node.state_flag_id, true)
			print_rich("[color=green]AddItemAction: Auto-set level flag '%s' to true.[/color]" % interactable_node.state_flag_id)

	return true
