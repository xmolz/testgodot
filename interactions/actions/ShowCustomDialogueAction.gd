class_name ShowCustomDialogueAction
extends Action

@export var dialogue_resource: DialogueResource
@export var dialogue_checkpoint: String = ""

func execute(interactable_node: Interactable) -> bool:
	if not dialogue_resource or dialogue_checkpoint.is_empty():
		push_warning("ShowCustomDialogueAction is not configured correctly.")
		return true

	if not DialogueManager or not GameManager:
		return true

	DialogueManager.dialogue_ended.connect(
		GameManager._on_dialogue_ended_for_object_dialogue,
		CONNECT_ONE_SHOT
	)

	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_checkpoint)
	return true
