# res://interactions/actions/startconversationaction.gd
class_name StartConversationAction
extends Action

# this action is very simple
# it intelligently uses the "character_conversation_overlay_scene"
# that is already assigned on the interactable itself.

func execute(interactable_node: Interactable) -> bool:
	# determine the conversation scene: prefer
	var conversation_scene: PackedScene = null
	if not interactable_node.character_conversation_scene_path.is_empty():
		conversation_scene = load(interactable_node.character_conversation_scene_path)
	elif interactable_node.character_conversation_overlay_scene:
		conversation_scene = interactable_node.character_conversation_overlay_scene

	if conversation_scene:
		# safety check for the gamemanager.
		if not GameManager:
			push_warning("GameManager not found. Cannot enter conversation state.")
			return true

		# tell the gamemanager to hide
		GameManager.enter_conversation_state()

		# instantiate the scene and add
		var conversation_instance = conversation_scene.instantiate()
		interactable_node.get_tree().root.add_child(conversation_instance)
		GameManager.register_character_conversation(conversation_instance)

		print_rich("[color=cyan]StartConversationAction: Launched conversation for '%s'.[/color]" % interactable_node.object_display_name)

		# very important: return false to
		# this leaves the game in the "conversation" state.
		return false
	else:
		# if no scene is assigned, the character can't talk.
		push_warning("StartConversationAction failed: No conversation scene assigned to '%s'." % interactable_node.object_display_name)
		# we can use the simple
		interactable_node.display_dialogue.emit("They don't seem to have much to say.")
		return true
