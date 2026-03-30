# res://interactions/actions/OpenMemoryBoxAction.gd
class_name OpenMemoryBoxAction
extends Action

const MemoryBoxScene = preload("res://MemoryBoxOverlay.tscn")

func execute(interactable_node: Interactable) -> Variant:
	if not MemoryBoxScene:
		push_warning("OpenMemoryBoxAction failed: Scene could not be loaded.")
		return true

	# 1. IRIS CLOSE TO BLACK
	if GameManager and GameManager.transition_layer:
		await GameManager.transition_layer.play_iris_close(1.0)

	# 2. SPAWN THE UI (While screen is black)
	if GameManager:
		GameManager.enter_conversation_state()

	var instance = MemoryBoxScene.instantiate()
	interactable_node.get_tree().root.add_child(instance)
	
	# Wait one frame so the UI can calculate its layout sizes
	await interactable_node.get_tree().process_frame

	# 3. TRIGGER RETRO BOOT SEQUENCE (Start this immediately!)
	if instance.has_method("play_boot_sequence"):
		instance.play_boot_sequence()

	# 4. IRIS OPEN (Revealing the dark background while the UI gracefully fades in)
	if GameManager and GameManager.transition_layer:
		await GameManager.transition_layer.play_iris_open(1.0) # Slower, chill open

	print_rich("[color=cyan]OpenMemoryBoxAction: Opened the Memory Box overlay.[/color]")

	return false
