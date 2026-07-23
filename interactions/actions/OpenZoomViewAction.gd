# res://interactions/actions/openzoomviewaction.gd
class_name OpenZoomViewAction
extends Action

# this action is simple and
# packedscene that is already configured

func execute(interactable_node: Interactable) -> bool:
	# first, check if the interactable
	if interactable_node.object_zoom_overlay_scene:
		# tell the gamemanager to prepare for the zoom state.
		if GameManager:
			GameManager.enter_zoom_view_state()

		# instantiate the scene and add it to the tree.
		var zoom_instance = interactable_node.object_zoom_overlay_scene.instantiate()
		interactable_node.get_tree().root.add_child(zoom_instance)

		print_rich("[color=cyan]OpenZoomViewAction: Opened zoom view for '%s'.[/color]" % interactable_node.object_display_name)

		# very important: return false to
		# this prevents the ui from
		return false
	else:
		# if no scene is assigned,
		push_warning("OpenZoomViewAction failed: No 'object_zoom_overlay_scene' assigned to '%s'." % interactable_node.object_display_name)
		interactable_node.display_dialogue.emit("It doesn't seem to open.")
		return true
