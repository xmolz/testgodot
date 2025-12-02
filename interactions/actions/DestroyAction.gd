# res://interactions/actions/DestroyAction.gd
class_name DestroyAction
extends Action

## An optional message to display just before the object is destroyed.
@export var message_on_destroy: String = ""


func execute(interactable_node: Interactable) -> bool:
	if not message_on_destroy.is_empty():
		interactable_node.display_dialogue.emit(message_on_destroy)

	# This logic is copied directly from your old _execute_action_details function.
	# It handles the special case where the interactable might be inside a UI
	# element (like a TextureButton) in a zoom view.
	var parent_node = interactable_node.get_parent()
	if parent_node is TextureButton:
		print_rich("[color=cyan]DestroyAction: Destroying parent TextureButton wrapper for '%s'.[/color]" % interactable_node.object_display_name)
		parent_node.queue_free()
		return true
	else:
		# If it's not in a UI wrapper, we just ask the Interactable to destroy itself.
		# We use the existing signal to ensure a clean, deferred removal.
		print_rich("[color=cyan]DestroyAction: Requesting self-destruction for '%s'.[/color]" % interactable_node.object_display_name)
		interactable_node.self_destruct_requested.emit()
		return true
