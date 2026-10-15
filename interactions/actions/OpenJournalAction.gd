class_name OpenJournalAction
extends Action
## step 2.200: opens a journal overlay (an instance of ui/journal_overlay.tscn with its own
## pages, e.g. ui/greene_journal_overlay.tscn) the same way GameManager.open_journal() opens
## Fiona's: conversation state and a paused tree. The overlay's journal_closed frees it and
## returns to the world through GameManager.exit_to_world_state().

@export var journal_scene: PackedScene


func execute(interactable_node: Interactable) -> Variant:
	if journal_scene == null:
		push_warning("OpenJournalAction: no journal_scene set on '%s'." % interactable_node.object_display_name)
		return true
	var tree := interactable_node.get_tree()
	if GameManager:
		GameManager.cancel_current_action(false)
		GameManager.persisting_verb_id = ""
	var overlay := journal_scene.instantiate()
	overlay.journal_closed.connect(func():
		if is_instance_valid(overlay):
			overlay.queue_free()
		if GameManager:
			GameManager.exit_to_world_state()
	)
	tree.root.add_child(overlay)
	if GameManager:
		GameManager.enter_conversation_state()
	tree.paused = true
	return false
