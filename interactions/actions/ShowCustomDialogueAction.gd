# res://interactions/actions/ShowCustomDialogueAction.gd
class_name ShowCustomDialogueAction
extends Action

@export var dialogue_resource: DialogueResource
@export var dialogue_checkpoint: String = ""

# Define the specific balloon scene
const BALLOON_SCENE_PATH = "res://conversationballoon.tscn"

# Change return type to Variant to allow 'await' to work correctly
func execute(interactable_node: Interactable) -> Variant:
	if not dialogue_resource or dialogue_checkpoint.is_empty():
		push_warning("ShowCustomDialogueAction is not configured correctly.")
		return true

	# 1. Start the dialogue using the CUSTOM SCENE
	# We use show_dialogue_balloon_scene to force our styled balloon
	DialogueManager.show_dialogue_balloon_scene(
		BALLOON_SCENE_PATH, 
		dialogue_resource, 
		dialogue_checkpoint
	)

	# 2. Wait for completion
	# We await the signal so the Action List pauses here.
	# (We do NOT connect to GameManager cleanup here, because Interactable.gd 
	# handles the cleanup after the whole list of actions is finished).
	await DialogueManager.dialogue_ended
	
	# 3. Return true to signal the Action List to continue (e.g. play sounds next)
	return true
