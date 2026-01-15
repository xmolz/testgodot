# res://interactions/actions/ShowCustomDialogueAction.gd
class_name ShowCustomDialogueAction
extends Action

@export var dialogue_resource: DialogueResource
@export var dialogue_checkpoint: String = ""

# Change return type to Variant to allow 'await' to work correctly
func execute(interactable_node: Interactable) -> Variant:
	if not dialogue_resource or dialogue_checkpoint.is_empty():
		push_warning("ShowCustomDialogueAction is not configured correctly.")
		return true

	# 1. Start the dialogue
	# Per Page 18 of docs, this returns a Node (the balloon), not a signal we can await directly.
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_checkpoint)

	# 2. Remove the specific GameManager connection!
	# We DO NOT want GameManager to unpause the player yet. 
	# The Interactable.gd script handles the final cleanup when the whole list is done.
	
	# 3. Wait for the signal defined on Page 12/18 of your docs.
	# This pauses this specific function here until the player closes the dialogue.
	await DialogueManager.dialogue_ended
	
	# 4. Now that dialogue is closed, return true to let Interactable.gd play the sound.
	return true
