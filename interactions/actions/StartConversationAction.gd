# res://interactions/actions/StartConversationAction.gd
class_name StartConversationAction
extends Action

# This action is very simple and requires no exported variables.
# It intelligently uses the "character_conversation_overlay_scene"
# that is already assigned on the Interactable itself.

func execute(interactable_node: Interactable) -> bool:
	# First, check if the Interactable has a conversation scene assigned.
	if interactable_node.character_conversation_overlay_scene:
		# Safety check for the GameManager.
		if not GameManager:
			push_warning("GameManager not found. Cannot enter conversation state.")
			return true # Fail gracefully, continue interaction cycle.

		# Tell the GameManager to hide the main UI and prepare for the conversation.
		GameManager.enter_conversation_state()

		# Instantiate the scene and add it to the root of the tree.
		var conversation_instance = interactable_node.character_conversation_overlay_scene.instantiate()
		interactable_node.get_tree().root.add_child(conversation_instance)

		# The old GameManager logic connected a signal to know when the conversation
		# was done. We must replicate that here to ensure the UI comes back!
		# We connect to the existing function on the GameManager.
		if conversation_instance.has_signal("conversation_finished"):
			conversation_instance.conversation_finished.connect(
				GameManager._on_character_conversation_finished,
				CONNECT_ONE_SHOT
			)

		print_rich("[color=cyan]StartConversationAction: Launched conversation for '%s'.[/color]" % interactable_node.object_display_name)

		# VERY IMPORTANT: Return false to stop the interaction cycle.
		# This leaves the game in the "conversation" state.
		return false
	else:
		# If no scene is assigned, the character can't talk.
		push_warning("StartConversationAction failed: No 'character_conversation_overlay_scene' assigned to '%s'." % interactable_node.object_display_name)
		# We can use the simple dialogue system for a fallback line.
		interactable_node.display_dialogue.emit("They don't seem to have much to say.")
		return true # Return true because the interaction is "over".
