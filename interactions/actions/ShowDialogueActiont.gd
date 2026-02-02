# res://interactions/actions/ShowDialogueAction.gd
class_name ShowDialogueAction
extends Action

@export var dialogue_resource: DialogueResource = preload("res://examinables.dialogue")

# Define the specific balloon scene to ensure visual consistency
const BALLOON_SCENE_PATH = "res://conversationballoon.tscn"

func execute(interactable_node: Interactable) -> bool:
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

	# --- Connect Signal to GameManager ---
	# This ensures UI is restored and player is unpaused when dialogue closes.
	DialogueManager.dialogue_ended.connect(
		GameManager._on_dialogue_ended_for_object_dialogue,
		CONNECT_ONE_SHOT
	)

	# --- Core Logic ---
	var target_object_id: String = interactable_node.object_id

	print_rich("[color=cyan]ShowDialogueAction: Showing custom balloon for '%s'[/color]" % target_object_id)

	# USE THE CUSTOM SCENE instead of the default project setting
	DialogueManager.show_dialogue_balloon_scene(
		BALLOON_SCENE_PATH, 
		dialogue_resource, 
		target_object_id
	)
	
	return true
