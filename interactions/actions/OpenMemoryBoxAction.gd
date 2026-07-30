# res://interactions/actions/openmemoryboxaction.gd
class_name OpenMemoryBoxAction
extends Action

const MEMORY_BOX_SCENE_PATH = "res://conversation/MemoryBoxOverlay.tscn"

func execute(interactable_node: Interactable) -> Variant:
	ResourceLoader.load_threaded_request(MEMORY_BOX_SCENE_PATH)

	# ///////////////////[1. enter ui state before fade]
	# this instantly hides the ui and locks player movement
	if GameManager:
		GameManager.cancel_current_action(false)
		GameManager.persisting_verb_id = ""
		GameManager.enter_conversation_state()

	if SoundManager and SoundManager.has_method("fade_out_all_ambience"):
		SoundManager.fade_out_all_ambience(1.0)

	# ---------------------[2. iris close to black]
	if GameManager and GameManager.transition_layer:
		await GameManager.transition_layer.play_iris_close(1.0)

	# Poll for completion of the threaded load
	var progress = []
	while true:
		var status = ResourceLoader.load_threaded_get_status(MEMORY_BOX_SCENE_PATH, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("OpenMemoryBoxAction: Threaded load failed for path: " + MEMORY_BOX_SCENE_PATH)
			return true
		await interactable_node.get_tree().process_frame

	var packed_scene = ResourceLoader.load_threaded_get(MEMORY_BOX_SCENE_PATH)
	if not packed_scene:
		push_warning("OpenMemoryBoxAction failed: Scene could not be loaded from " + MEMORY_BOX_SCENE_PATH)
		return true

	# spawn the ui safely (while screen is black)
	var instance = packed_scene.instantiate()
	interactable_node.get_tree().root.add_child.call_deferred(instance)

	await interactable_node.get_tree().process_frame

	# -----------------------[4. trigger retro boot sequence]
	if instance.has_method("play_boot_sequence"):
		instance.play_boot_sequence()

	# ////////////////////[5. iris open]
	if GameManager and GameManager.transition_layer:
		await GameManager.transition_layer.play_iris_open(1.0)

	print_rich("[color=cyan]OpenMemoryBoxAction: Opened the Memory Box overlay.[/color]")

	DebugVRAM.snapshot("memory box opened")
	return false
