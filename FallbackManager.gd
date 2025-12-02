# res://scripts/FallbackManager.gd
extends Node

const DEFAULT_CHECKPOINT_NAME = "start"

func trigger_fallback(verb_data: VerbData, object_id: String, item_id: String):
	if not is_instance_valid(verb_data):
		push_warning("FallbackManager: trigger_fallback was called with invalid VerbData.")
		return

	var fallback_resource = verb_data.fallback_dialogue_file
	if not is_instance_valid(fallback_resource):
		print_rich("[color=orange]FallbackManager: Verb '%s' has no fallback file assigned. No action taken.[/color]" % verb_data.verb_id)
		GameManager.interaction_complete.emit()
		return

	var checkpoint_to_use: String = _find_valid_checkpoint(fallback_resource, object_id, item_id)

	DialogueManager.dialogue_ended.connect(
		GameManager._on_dialogue_ended_for_object_dialogue,
		CONNECT_ONE_SHOT
	)

	print_rich("[color=cyan]FallbackManager: Triggering fallback dialogue from '%s' with checkpoint '%s'.[/color]" % [fallback_resource.resource_path, checkpoint_to_use])
	DialogueManager.show_dialogue_balloon(fallback_resource, checkpoint_to_use)


# This function now uses the correct method to check for checkpoints.
func _find_valid_checkpoint(resource: DialogueResource, object_id: String, item_id: String) -> String:
	# Level 1: Item + Object Combination
	if not item_id.is_empty():
		var item_specific_checkpoint = "%s_item_%s" % [object_id, item_id]
		# Use the confirmed method: check the 'titles' dictionary directly.
		if resource.titles.has(item_specific_checkpoint):
			print_rich("[color=green]FallbackManager: Found item-specific checkpoint: '%s'[/color]" % item_specific_checkpoint)
			return item_specific_checkpoint

	# Level 2: Object-Only
	if not object_id.is_empty():
		var object_specific_checkpoint = object_id
		if resource.titles.has(object_specific_checkpoint):
			print_rich("[color=green]FallbackManager: Found object-specific checkpoint: '%s'[/color]" % object_specific_checkpoint)
			return object_specific_checkpoint

	# Level 3: Generic Default
	print_rich("[color=yellow]FallbackManager: No specific checkpoint found. Using default: '%s'[/color]" % DEFAULT_CHECKPOINT_NAME)
	return DEFAULT_CHECKPOINT_NAME
