# res://interactions/actions/showcustomdialogueaction.gd
class_name ShowCustomDialogueAction
extends Action

@export var dialogue_resource: DialogueResource
@export var dialogue_checkpoint: String = ""

# define the specific balloon scene
const BALLOON_SCENE_PATH = "res://conversation/conversationballoon.tscn"

# change return type to variant
func execute(interactable_node: Interactable) -> Variant:
	if not dialogue_resource or dialogue_checkpoint.is_empty():
		push_warning("ShowCustomDialogueAction is not configured correctly.")
		return true

	# -------------------(safety check)
	# ensure the checkpoint actually exists
	var safe_checkpoint = dialogue_checkpoint
	if not dialogue_resource.titles.has(safe_checkpoint):
		push_warning("Dialogue checkpoint '%s' not found in resource! Falling back to 'start'." % safe_checkpoint)
		safe_checkpoint = "start"

	# start the dialogue using the custom scene
	DialogueManager.show_dialogue_balloon_scene(
		BALLOON_SCENE_PATH,
		dialogue_resource,
		safe_checkpoint
	)

	# wait for completion
	await DialogueManager.dialogue_ended

	# return true to signal the action list to continue
	return true
