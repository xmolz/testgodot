# res://interactions/actions/destroyaction.gd
class_name DestroyAction
extends Action

# an optional message to display
@export var message_on_destroy: String = ""


func execute(interactable_node: Interactable) -> bool:
	if not message_on_destroy.is_empty():
		interactable_node.display_dialogue.emit(message_on_destroy)

	# this logic is copied directly
	# it handles the special case
	# element (like a texturebutton) in a zoom view.
	var parent_node = interactable_node.get_parent()
	if parent_node is TextureButton:
		print_rich("[color=cyan]DestroyAction: Destroying parent TextureButton wrapper for '%s'.[/color]" % interactable_node.object_display_name)
		parent_node.queue_free()
		return true
	else:
		# if it's not in a
		# we use the existing signal
		print_rich("[color=cyan]DestroyAction: Requesting self-destruction for '%s'.[/color]" % interactable_node.object_display_name)
		interactable_node.self_destruct_requested.emit()
		return true
