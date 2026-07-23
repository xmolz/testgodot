# res://interactions/actions/showdialogueactiont.gd
class_name ShowDialogueAction
extends Action

@export var dialogue_resource: DialogueResource = preload("res://dialogue/examinables.dialogue")

# define the specific balloon scene
const BALLOON_SCENE_PATH = "res://conversation/conversationballoon.tscn"

func execute(interactable_node: Interactable) -> Variant:
	# ***********************[safety checks]
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

	# *********** core logic
	var target_object_id: String = interactable_node.object_id

	# safety check: if the dialogue
	var checkpoint_to_use: String = target_object_id
	if dialogue_resource and not dialogue_resource.titles.has(checkpoint_to_use):
		checkpoint_to_use = "start"

	print_rich("[color=cyan]ShowDialogueAction: Showing custom balloon for '%s' (Resolved to: '%s')[/color]" % [target_object_id, checkpoint_to_use])

	# use the custom scene instead
	DialogueManager.show_dialogue_balloon_scene(
		BALLOON_SCENE_PATH,
		dialogue_resource,
		checkpoint_to_use
	)

	await DialogueManager.dialogue_ended

	return true
