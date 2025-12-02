# res://interactions/actions/ShowDialogueAction.gd
class_name ShowDialogueAction
extends Action

# We still keep our convenient default preloaded resource.
@export var dialogue_resource: DialogueResource = preload("res://examinables.dialogue")


# Override the base execute method with our updated logic.
func execute(interactable_node: Interactable) -> bool:
	# --- Safety Checks ---
	if not dialogue_resource:
		push_warning("ShowDialogueAction on '%s' has no DialogueResource assigned." % interactable_node.object_display_name)
		return true

	if not DialogueManager:
		push_warning("DialogueManager autoload not found. Cannot show dialogue.")
		return true

	# NEW SAFETY CHECK for the GameManager.
	if not GameManager:
		push_warning("GameManager autoload not found. Cannot connect signals to restore UI.")
		return true

	if interactable_node.object_id.is_empty():
		push_warning("Interactable '%s' has an empty object_id. Dialogue may not work correctly." % interactable_node.object_display_name)

	# --- NEW LOGIC: Restore the crucial signal connection! ---
	# The GameManager has the function `_on_dialogue_ended_for_object_dialogue`
	# which is responsible for cleaning up, restoring the UI, and completing the cycle.
	# We connect to it here, just before starting the dialogue, using CONNECT_ONE_SHOT
	# so it automatically disconnects after being triggered once. This is exactly
	# what the old GameManager code used to do.
	DialogueManager.dialogue_ended.connect(
		GameManager._on_dialogue_ended_for_object_dialogue,
		CONNECT_ONE_SHOT
	)

	# --- Core Logic (this part is unchanged) ---
	var target_object_id: String = interactable_node.object_id

	print_rich("[color=cyan]ShowDialogueAction: Requesting DialogueManager to show balloon from resource '%s' for object_id '%s'[/color]" % [dialogue_resource.resource_path, target_object_id])

	DialogueManager.show_dialogue_balloon(dialogue_resource, target_object_id)
	return true
