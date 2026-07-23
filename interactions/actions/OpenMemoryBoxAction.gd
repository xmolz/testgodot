# res://interactions/actions/openmemoryboxaction.gd
class_name OpenMemoryBoxAction
extends Action

const MemoryBoxScene = preload("res://conversation/MemoryBoxOverlay.tscn")

func execute(interactable_node: Interactable) -> Variant:
	if not MemoryBoxScene:
		push_warning("OpenMemoryBoxAction failed: Scene could not be loaded.")
		return true

	# ///////////////////[1. enter ui state before fade]
	# this instantly hides the ui and locks player movement
	if GameManager:
		GameManager.cancel_current_action(false)
		GameManager.persisting_verb_id = ""
		GameManager.enter_conversation_state()

	# ---------------------[2. iris close to black]
	if GameManager and GameManager.transition_layer:
		await GameManager.transition_layer.play_iris_close(1.0)

	# spawn the ui (while screen is black)
	var instance = MemoryBoxScene.instantiate()
	interactable_node.get_tree().root.add_child(instance)

	await interactable_node.get_tree().process_frame

	# -----------------------[4. trigger retro boot sequence]
	if instance.has_method("play_boot_sequence"):
		instance.play_boot_sequence()

	# ////////////////////[5. iris open]
	if GameManager and GameManager.transition_layer:
		await GameManager.transition_layer.play_iris_open(1.0)

	print_rich("[color=cyan]OpenMemoryBoxAction: Opened the Memory Box overlay.[/color]")

	return false
