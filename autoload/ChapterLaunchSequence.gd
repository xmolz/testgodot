# chapterlaunchsequence.gd
extends Node

var _launching: bool = false

func launch(data: MemoryChapterData, overlay: CanvasLayer, drawer: Control) -> void:
	if _launching:
		return
	_launching = true

	var path = data.scene_path_to_load

	# grab drawer art texture and global rect before drawer is closed
	var portal_texture: Texture2D = null
	var start_rect: Rect2 = Rect2()
	if is_instance_valid(drawer):
		if drawer.has_method("get_detail_texture"):
			portal_texture = drawer.get_detail_texture()
		if drawer.has_method("get_detail_image_global_rect"):
			start_rect = drawer.get_detail_image_global_rect()

	# 1. empty path (test slice)
	if path.is_empty():
		# fade overlay and drawer
		var fade = create_tween().set_parallel(true).bind_node(overlay)
		if is_instance_valid(overlay) and "panel" in overlay:
			fade.tween_property(overlay.panel, "modulate:a", 0.0, 0.35)
		if is_instance_valid(drawer):
			fade.tween_property(drawer, "modulate:a", 0.0, 0.35)
		await fade.finished

		# portal enter
		if GameManager and is_instance_valid(GameManager.transition_layer):
			await GameManager.transition_layer.portal_enter(portal_texture, start_rect)

		# play monologue/hold during test slice
		if GameManager and is_instance_valid(GameManager.transition_layer):
			await GameManager.transition_layer.play_portal_monologue(data.launch_monologue)

		# portal exit
		if GameManager and is_instance_valid(GameManager.transition_layer):
			await GameManager.transition_layer.portal_exit()

		# restore and clean up
		if is_instance_valid(overlay) and "panel" in overlay:
			overlay.panel.modulate.a = 1.0
		if is_instance_valid(drawer):
			drawer.close()

		if NotificationManager:
			NotificationManager.add_notification("Portal complete — chapter launch pipeline not built yet.")

		_launching = false
		return

	# 2. non-empty path (real launch pipeline)
	# fade overlay and drawer
	var fade = create_tween().set_parallel(true).bind_node(overlay)
	if is_instance_valid(overlay) and "panel" in overlay:
		fade.tween_property(overlay.panel, "modulate:a", 0.0, 0.35)
	if is_instance_valid(drawer):
		fade.tween_property(drawer, "modulate:a", 0.0, 0.35)
	await fade.finished

	# await portal enter
	if GameManager and is_instance_valid(GameManager.transition_layer):
		await GameManager.transition_layer.portal_enter(portal_texture, start_rect)

	# start threaded background load and monologue under the hold
	ResourceLoader.load_threaded_request(path)

	var monologue_finished = false
	var load_monologue_task = func():
		if GameManager and is_instance_valid(GameManager.transition_layer):
			await GameManager.transition_layer.play_portal_monologue(data.launch_monologue)
		monologue_finished = true

	# run monologue in background (it is awaitable)
	load_monologue_task.call()

	# free the overlay immediately so it doesn't survive the scene change
	if is_instance_valid(overlay):
		overlay.queue_free()
	
	DebugVRAM.snapshot("after overlay freed")

	# poll load status while waiting for monologue to finish
	var progress = []
	var loaded_packed_scene: PackedScene = null
	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			loaded_packed_scene = ResourceLoader.load_threaded_get(path)
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("ChapterLaunchSequence: Threaded load failed for path: " + path)
			if GameManager and is_instance_valid(GameManager.transition_layer):
				GameManager.transition_layer.portal_abort()
			if NotificationManager:
				NotificationManager.add_notification("Chapter failed to load.")
			_launching = false
			return
		await get_tree().process_frame

	# wait until monologue is also finished
	while not monologue_finished:
		await get_tree().process_frame

	# switch scene
	if loaded_packed_scene:
		get_tree().change_scene_to_packed(loaded_packed_scene)
	await get_tree().process_frame

	DebugVRAM.snapshot("after scene change")

	# ready gate: await first_visuals_ready with 5s timeout or await one extra frame
	var current_scene = get_tree().current_scene
	if is_instance_valid(current_scene) and current_scene.has_signal("first_visuals_ready"):
		var ready_flag = false
		current_scene.first_visuals_ready.connect(func(): ready_flag = true)
		
		# 5-second timeout fallback
		var elapsed = 0.0
		while not ready_flag and elapsed < 5.0:
			await get_tree().process_frame
			elapsed += get_process_delta_time()
	else:
		await get_tree().process_frame

	# reset interaction state
	if GameManager:
		GameManager.enter_chapter_state()

	# portal exit
	if GameManager and is_instance_valid(GameManager.transition_layer):
		await GameManager.transition_layer.portal_exit()

	_launching = false
