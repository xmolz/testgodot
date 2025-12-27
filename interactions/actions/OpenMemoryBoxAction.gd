# res://interactions/actions/OpenMemoryBoxAction.gd
class_name OpenMemoryBoxAction
extends Action

# We preload the scene this action is responsible for opening.
const MemoryBoxScene = preload("res://MemoryBoxOverlay.tscn") # <-- IMPORTANT: Verify this path!

func execute(interactable_node: Interactable) -> bool:
	if not MemoryBoxScene:
		push_warning("OpenMemoryBoxAction failed: Scene could not be loaded.")
		return true


	if GameManager:
		GameManager.enter_conversation_state()

	# Tell the GameManager to handle any state changes if necessary.
	# For example, GameManager.enter_overlay_state()

	var instance = MemoryBoxScene.instantiate()
	interactable_node.get_tree().root.add_child(instance)

	print_rich("[color=cyan]OpenMemoryBoxAction: Opened the Memory Box overlay.[/color]")

	# VERY IMPORTANT: Return false to stop the interaction cycle.
	return false
