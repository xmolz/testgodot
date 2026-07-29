# chapterlaunchsequence.gd
extends Node

# TODO: flip off after stutter investigation
const PORTAL_DEBUG := true

var _launching: bool = false

var _preloaded_dialogue_resource: DialogueResource = null
var _preloaded_balloon_scene: PackedScene = null

func launch(data: MemoryChapterData, overlay: CanvasLayer, drawer: Control) -> void:
	if _launching:
		return
	_launching = true

	if PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] launch() entered at %d ms[/color]" % Time.get_ticks_msec())

	# Front-load loads before any visual change
	var monologue_title = data.launch_dialogue_title
	_preloaded_dialogue_resource = null
	_preloaded_balloon_scene = null

	if not monologue_title.strip_edges().is_empty():
		if ResourceLoader.exists("res://dialogue/chapter_launch.dialogue"):
			_preloaded_dialogue_resource = load("res://dialogue/chapter_launch.dialogue") as DialogueResource
		if ResourceLoader.exists("res://conversation/conversationballoon.tscn"):
			_preloaded_balloon_scene = load("res://conversation/conversationballoon.tscn") as PackedScene

	if PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] loads completed at %d ms[/color]" % Time.get_ticks_msec())

	var path = data.scene_path_to_load

	# Pre-flight check: if non-empty path does not exist, fall back to empty path test behavior!
	var real_path_exists = false
	if not path.is_empty():
		if ResourceLoader.exists(path):
			real_path_exists = true
			ResourceLoader.load_threaded_request(path)
			if PORTAL_DEBUG:
				print_rich("[color=magenta][PORTAL DEBUG] scene load requested: %s at %d ms[/color]" % [path, Time.get_ticks_msec()])
		else:
			push_error("ChapterLaunchSequence: scene path '%s' does not exist! Falling back to test-slice behavior." % path)
			path = "" # forces empty path test-slice fallback branch

	# grab drawer art texture and global rect before drawer is closed
	var portal_texture: Texture2D = null
	var start_rect: Rect2 = Rect2()
	if is_instance_valid(drawer):
		if drawer.has_method("get_detail_texture"):
			portal_texture = drawer.get_detail_texture()
		if drawer.has_method("get_detail_image_global_rect"):
			start_rect = drawer.get_detail_image_global_rect()

	if PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] fade started at %d ms[/color]" % Time.get_ticks_msec())

	# 1. empty path (test slice)
	if path.is_empty():
		# fade overlay and drawer (no await, parallel with grow)
		var fade = create_tween().set_parallel(true).bind_node(overlay)
		if is_instance_valid(overlay) and "panel" in overlay:
			fade.tween_property(overlay.panel, "modulate:a", 0.0, 0.35)
		if is_instance_valid(drawer):
			fade.tween_property(drawer, "modulate:a", 0.0, 0.35)

		# portal enter called
		if PORTAL_DEBUG:
			print_rich("[color=magenta][PORTAL DEBUG] portal_enter called at %d ms[/color]" % Time.get_ticks_msec())

		if GameManager and is_instance_valid(GameManager.transition_layer):
			await GameManager.transition_layer.portal_enter(portal_texture, start_rect)

		# immediately release portal_texture reference once enter finishes
		portal_texture = null

		# play monologue/hold during test slice
		if GameManager and is_instance_valid(GameManager.transition_layer):
			await GameManager.transition_layer.play_portal_monologue(monologue_title, _preloaded_dialogue_resource, _preloaded_balloon_scene)

		# immediately release preloaded references once done
		_preloaded_dialogue_resource = null
		_preloaded_balloon_scene = null

		# portal_exit started
		if PORTAL_DEBUG:
			print_rich("[color=magenta][PORTAL DEBUG] portal_exit called at %d ms[/color]" % Time.get_ticks_msec())

		if GameManager and is_instance_valid(GameManager.transition_layer):
			await GameManager.transition_layer.portal_exit()

		# restore and clean up
		if is_instance_valid(overlay) and "panel" in overlay:
			overlay.panel.modulate.a = 1.0
		if is_instance_valid(drawer):
			drawer.close()

		overlay = null
		drawer = null

		if NotificationManager:
			NotificationManager.add_notification("Portal complete — chapter launch pipeline not built yet.")

		_launching = false
		return

	# 2. non-empty path (real launch pipeline)
	# fade overlay and drawer (no await, parallel with grow)
	var fade = create_tween().set_parallel(true).bind_node(overlay)
	if is_instance_valid(overlay) and "panel" in overlay:
		fade.tween_property(overlay.panel, "modulate:a", 0.0, 0.35)
	if is_instance_valid(drawer):
		fade.tween_property(drawer, "modulate:a", 0.0, 0.35)

	# portal enter called
	if PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] portal_enter called at %d ms[/color]" % Time.get_ticks_msec())

	if GameManager and is_instance_valid(GameManager.transition_layer):
		await GameManager.transition_layer.portal_enter(portal_texture, start_rect)

	# immediately release portal_texture reference once enter finishes
	portal_texture = null

	var monologue_finished = false
	var load_monologue_task = func():
		if GameManager and is_instance_valid(GameManager.transition_layer):
			await GameManager.transition_layer.play_portal_monologue(monologue_title, _preloaded_dialogue_resource, _preloaded_balloon_scene)
		monologue_finished = true

	# run monologue in background (it is awaitable)
	load_monologue_task.call()

	# free the overlay immediately so it doesn't survive the scene change (hold is established)
	if is_instance_valid(overlay):
		overlay.queue_free()
	
	overlay = null
	drawer = null
	
	await get_tree().process_frame
	await get_tree().process_frame

	if PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] overlay freed at %d ms[/color]" % Time.get_ticks_msec())

	DebugVRAM.snapshot("after overlay freed")

	# poll load status while waiting for monologue to finish
	var progress = []
	var loaded_packed_scene: PackedScene = null
	var _load_wait_start := Time.get_ticks_msec()
	var _last_status := -1

	while true:
		var status = ResourceLoader.load_threaded_get_status(path, progress)

		if PORTAL_DEBUG and status != _last_status:
			print_rich("[color=magenta][PORTAL DEBUG] scene load status changed: %d at %d ms[/color]" % [status, Time.get_ticks_msec()])
			_last_status = status

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			loaded_packed_scene = ResourceLoader.load_threaded_get(path)
			if PORTAL_DEBUG:
				print_rich("[color=magenta][PORTAL DEBUG] scene load completed at %d ms[/color]" % Time.get_ticks_msec())
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("ChapterLaunchSequence: threaded load failed (status %d) for: %s" % [status, path])
			await _abort_launch_revealing_world()
			return
		elif Time.get_ticks_msec() - _load_wait_start > 15000:
			push_error("ChapterLaunchSequence: scene load timed out for: " + path)
			await _abort_launch_revealing_world()
			return
		await get_tree().process_frame

	# wait until monologue is also finished
	while not monologue_finished:
		await get_tree().process_frame

	if loaded_packed_scene == null:
		push_error("ChapterLaunchSequence: loaded scene packed is null for: " + path)
		await _abort_launch_revealing_world()
		return

	# release preloaded monologue references
	_preloaded_dialogue_resource = null
	_preloaded_balloon_scene = null

	# switch scene
	if loaded_packed_scene:
		get_tree().change_scene_to_packed(loaded_packed_scene)
	await get_tree().process_frame

	# immediately release the packed scene reference
	loaded_packed_scene = null

	if PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] scene swap called at %d ms[/color]" % Time.get_ticks_msec())

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

	# TODO: reverse portal (chapter -> main) hooks in here.

	# portal_exit started
	if PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] portal_exit called at %d ms[/color]" % Time.get_ticks_msec())

	if GameManager and is_instance_valid(GameManager.transition_layer):
		await GameManager.transition_layer.portal_exit()

	_launching = false

func _abort_launch_revealing_world() -> void:
	if GameManager and is_instance_valid(GameManager.transition_layer):
		# fade and abort portal
		await GameManager.transition_layer.portal_fade_abort(0.4)
	
	if NotificationManager:
		NotificationManager.add_notification("The memory slips away... (chapter failed to load)")
	
	if GameManager:
		GameManager.enter_chapter_state()
	
	_launching = false
	
	# release all preloaded references
	_preloaded_dialogue_resource = null
	_preloaded_balloon_scene = null
