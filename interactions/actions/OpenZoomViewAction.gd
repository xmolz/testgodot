# res://interactions/actions/OpenZoomViewAction.gd
class_name OpenZoomViewAction
extends Action

# This action is simple and needs no exported variables. It uses the
# PackedScene that is already configured on the Interactable itself.

func execute(interactable_node: Interactable) -> bool:
	# First, check if the Interactable has a zoom scene assigned.
	if interactable_node.object_zoom_overlay_scene:
		# Tell the GameManager to prepare for the zoom state.
		if GameManager:
			GameManager.enter_zoom_view_state()

		# Instantiate the scene and add it to the tree.
		var zoom_instance = interactable_node.object_zoom_overlay_scene.instantiate()
		interactable_node.get_tree().root.add_child(zoom_instance)

		print_rich("[color=cyan]OpenZoomViewAction: Opened zoom view for '%s'.[/color]" % interactable_node.object_display_name)

		# VERY IMPORTANT: Return false to stop the interaction cycle.
		# This prevents the UI from resetting while the zoom view is open.
		return false
	else:
		# If no scene is assigned, print an error and continue normally.
		push_warning("OpenZoomViewAction failed: No 'object_zoom_overlay_scene' assigned to '%s'." % interactable_node.object_display_name)
		interactable_node.display_dialogue.emit("It doesn't seem to open.")
		return true
