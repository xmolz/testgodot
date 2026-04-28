# res://interactions/actions/ShowDialogueAction.gd
class_name ShowDialogueAction
extends Action

@export var dialogue_resource: DialogueResource = preload("res://examinables.dialogue")

# Define the specific balloon scene to ensure visual consistency
const BALLOON_SCENE_PATH = "res://conversationballoon.tscn"

func execute(interactable_node: Interactable) -> Variant:
	# --- Safety Checks ---
	if not dialogue_resource:
		push_warning("ShowDialogueAction on '%s' has no DialogueResource assigned." % interactable_node.object_display_name)
		return true

	if not DialogueManager:
		push_warning("DialogueManager autoload not found.")
		return true

	if not GameManager:
		push_warning("GameManager autoload not found.")
		return true

	if interactable_node.object_id.is_empty():
		push_warning("Interactable '%s' has an empty object_id." % interactable_node.object_display_name)

	# --- Core Logic ---
	var target_object_id: String = interactable_node.object_id

	# Safety check: if the dialogue file doesn't have this specific object's ID, fall back to "~ start"
	var checkpoint_to_use: String = target_object_id
	if dialogue_resource and not dialogue_resource.titles.has(checkpoint_to_use):
		checkpoint_to_use = "start"

	print_rich("[color=cyan]ShowDialogueAction: Showing custom balloon for '%s' (Resolved to: '%s')[/color]" % [target_object_id, checkpoint_to_use])

	# USE THE CUSTOM SCENE instead of the default project setting
	DialogueManager.show_dialogue_balloon_scene(
		BALLOON_SCENE_PATH,
		dialogue_resource,
		checkpoint_to_use
	)

	await DialogueManager.dialogue_ended

	return true
