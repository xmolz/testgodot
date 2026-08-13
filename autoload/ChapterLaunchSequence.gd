# chapterlaunchsequence.gd
extends Node

# TODO: flip off after stutter investigation
const PORTAL_DEBUG := true

const HUB_SCENE_PATH := "res://main.tscn"

var _launching: bool = false

# display name of the chapter currently being played, for save metadata. set on launch,
# cleared on return or launch abort.
var active_chapter_name: String = ""
var _intro_conversation_finished: bool = false

var _preloaded_dialogue_resource: DialogueResource = null
var _preloaded_balloon_scene: PackedScene = null

func is_launching() -> bool:
	return _launching

func launch(data: MemoryChapterData, overlay: CanvasLayer, drawer: Control) -> void:
	if _launching:
		return
	_launching = true
	active_chapter_name = data.chapter_name

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
	var intro_path = data.intro_overlay_path
	var has_intro_overlay = false

	# Pre-flight check: if non-empty path does not exist, fall back to empty path test behavior!
	var real_path_exists = false
	if not path.is_empty():
		if ResourceLoader.exists(path):
			real_path_exists = true
			ResourceLoader.load_threaded_request(path)
			if PORTAL_DEBUG:
				print_rich("[color=magenta][PORTAL DEBUG] scene load requested: %s at %d ms[/color]" % [path, Time.get_ticks_msec()])
			
			# Front-load intro overlay if defined
			if not intro_path.strip_edges().is_empty():
				if ResourceLoader.exists(intro_path):
					has_intro_overlay = true
					ResourceLoader.load_threaded_request(intro_path)
					if PORTAL_DEBUG:
						print_rich("[color=magenta][PORTAL DEBUG] intro overlay load requested: %s at %d ms[/color]" % [intro_path, Time.get_ticks_msec()])
				else:
					push_warning("ChapterLaunchSequence: intro overlay path '%s' does not exist." % intro_path)
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

		# 1a. optional in-place intro sequence: no level to load, so the dream + wake CG play
		# over the hub and hand the player straight back to the memory box afterwards.
		var intro_instance: Node = null
		var wake_layer: Node = null

		if not intro_path.strip_edges().is_empty() and ResourceLoader.exists(intro_path):
			var intro_packed: PackedScene = load(intro_path)
			if intro_packed:
				# the wake layer must exist before the balloon spawns so the dialogue can reach it
				if not data.wake_cg_scene_path.strip_edges().is_empty() and ResourceLoader.exists(data.wake_cg_scene_path):
					var wake_packed: PackedScene = load(data.wake_cg_scene_path)
					if wake_packed:
						wake_layer = wake_packed.instantiate()
						get_tree().root.add_child(wake_layer)

				intro_instance = intro_packed.instantiate()
				if "autostart" in intro_instance:
					intro_instance.autostart = false
				if is_instance_valid(wake_layer) and "extra_game_states" in intro_instance:
					intro_instance.extra_game_states = [wake_layer]
				_intro_conversation_finished = false
				intro_instance.conversation_finished.connect(
					_on_intro_conversation_finished, CONNECT_ONE_SHOT)
				get_tree().root.add_child(intro_instance)

				# let _ready() run so @onready refs exist, then stage the opening CG while
				# the portal flash still hides it.
				await get_tree().process_frame
				await get_tree().process_frame
				if intro_instance.has_method("prestage_visuals"):
					await intro_instance.prestage_visuals()
		elif not intro_path.strip_edges().is_empty():
			push_warning("ChapterLaunchSequence: intro overlay path '%s' does not exist." % intro_path)

		# portal_exit started
		if PORTAL_DEBUG:
			print_rich("[color=magenta][PORTAL DEBUG] portal_exit called at %d ms[/color]" % Time.get_ticks_msec())

		if GameManager and is_instance_valid(GameManager.transition_layer):
			await GameManager.transition_layer.portal_exit()

		# only now, with the flash gone and the dream already visible, let the dialogue run.
		if is_instance_valid(intro_instance):
			if intro_instance.has_method("begin_conversation"):
				intro_instance.begin_conversation()
			# is_instance_valid() in the condition is load-bearing: the overlay frees itself
			# shortly after emitting, so this loop can never hang even if the signal is missed.
			while is_instance_valid(intro_instance) and not _intro_conversation_finished:
				await get_tree().process_frame

		# restore the memory box UNDER the wake CG, then fade the CG out onto it
		if is_instance_valid(overlay) and "panel" in overlay:
			overlay.panel.modulate.a = 1.0
		if is_instance_valid(drawer):
			drawer.close()

		if is_instance_valid(wake_layer):
			if wake_layer.has_method("wait_for_pan"):
				await wake_layer.wait_for_pan()
			await get_tree().create_timer(0.5).timeout
			if wake_layer.has_method("fade_out"):
				await wake_layer.fade_out(0.7)
			wake_layer.queue_free()

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

	# play monologue/hold during real launch
	if GameManager and is_instance_valid(GameManager.transition_layer):
		await GameManager.transition_layer.play_portal_monologue(monologue_title, _preloaded_dialogue_resource, _preloaded_balloon_scene)

	# release preloaded monologue references immediately
	_preloaded_dialogue_resource = null
	_preloaded_balloon_scene = null

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

	# poll load status sequentially (state-based polling loop)
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

	if loaded_packed_scene == null:
		push_error("ChapterLaunchSequence: loaded scene packed is null for: " + path)
		await _abort_launch_revealing_world()
		return

	# Load intro overlay scene if requested and registered
	var loaded_intro_scene: PackedScene = null
	if has_intro_overlay:
		var _intro_wait_start := Time.get_ticks_msec()
		while true:
			var status = ResourceLoader.load_threaded_get_status(intro_path)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				loaded_intro_scene = ResourceLoader.load_threaded_get(intro_path)
				break
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_warning("ChapterLaunchSequence: intro overlay load failed (status %d) for: %s" % [status, intro_path])
				has_intro_overlay = false
				break
			elif Time.get_ticks_msec() - _intro_wait_start > 10000:
				push_warning("ChapterLaunchSequence: intro overlay load timed out.")
				has_intro_overlay = false
				break
			await get_tree().process_frame

	# stash hub progress and free the hub under the flash. the hub is a SceneDirector root
	# child, NOT the current_scene, so change_scene_to_packed() alone leaves it alive for
	# the whole chapter (duplicated player group, alpha-stacked hud, held vram).
	if SaveManager and SaveManager.has_method("stash_hub_state"):
		SaveManager.stash_hub_state()
	if SceneDirector and is_instance_valid(SceneDirector.current_game_scene):
		SceneDirector.teardown_game_scene()
		await get_tree().process_frame
		DebugVRAM.snapshot("launch: hub freed")

	# switch scene
	if loaded_packed_scene:
		get_tree().change_scene_to_packed(loaded_packed_scene)
	await get_tree().process_frame

	if SoundManager and SoundManager.has_method("clear_ambience_snapshot"):
		SoundManager.clear_ambience_snapshot()

	# immediately release the packed scene reference
	loaded_packed_scene = null

	if PORTAL_DEBUG:
		print_rich("[color=magenta][PORTAL DEBUG] scene swap called at %d ms[/color]" % Time.get_ticks_msec())

	DebugVRAM.snapshot("after scene change")

	# instantiate the intro overlay above the swapped level, but do NOT let it talk yet.
	var intro_instance: Node = null
	var wake_layer: Node = null
	_intro_conversation_finished = false

	# the wake CG layer must exist before the balloon spawns so the dialogue can reach it.
	# it stays invisible until the dialogue stages it under the blackout.
	if has_intro_overlay and loaded_intro_scene and not data.wake_cg_scene_path.strip_edges().is_empty():
		if ResourceLoader.exists(data.wake_cg_scene_path):
			var wake_packed: PackedScene = load(data.wake_cg_scene_path)
			if wake_packed:
				wake_layer = wake_packed.instantiate()
				get_tree().root.add_child(wake_layer)
				DebugVRAM.snapshot("launch: wake cg staged")

	if has_intro_overlay and loaded_intro_scene:
		intro_instance = loaded_intro_scene.instantiate()

		# must be set before _ready() runs, or the balloon spawns under the portal flash.
		if "autostart" in intro_instance:
			intro_instance.autostart = false

		if is_instance_valid(wake_layer) and "extra_game_states" in intro_instance:
			intro_instance.extra_game_states = [wake_layer]

		intro_instance.conversation_finished.connect(
			_on_intro_conversation_finished, CONNECT_ONE_SHOT)

		get_tree().root.add_child.call_deferred(intro_instance)
		loaded_intro_scene = null # release pack reference

		# let the deferred add_child flush so _ready() ran and @onready refs exist.
		await get_tree().process_frame
		await get_tree().process_frame

		if PORTAL_DEBUG:
			print_rich("[color=magenta][PORTAL DEBUG] intro overlay staged at %d ms[/color]" % Time.get_ticks_msec())

		# stage the opening CG while the flash still hides it.
		if is_instance_valid(intro_instance) and intro_instance.has_method("prestage_visuals"):
			await intro_instance.prestage_visuals()
			if PORTAL_DEBUG:
				print_rich("[color=magenta][PORTAL DEBUG] intro visuals prestaged at %d ms[/color]" % Time.get_ticks_msec())

	# clear the portal. TransitionLayer.portal_exit() prints its own debug line, so this
	# function deliberately does not print one (that was the duplicated log entry).
	if GameManager and is_instance_valid(GameManager.transition_layer):
		await GameManager.transition_layer.portal_exit()

	# only now, with the flash gone and the CG already visible, let the dialogue run.
	if is_instance_valid(intro_instance):
		if intro_instance.has_method("begin_conversation"):
			intro_instance.begin_conversation()
			if PORTAL_DEBUG:
				print_rich("[color=magenta][PORTAL DEBUG] intro conversation started at %d ms[/color]" % Time.get_ticks_msec())

		# is_instance_valid() in the condition is load-bearing: the overlay frees itself shortly
		# after emitting, so this loop can never hang even if the signal is missed.
		while is_instance_valid(intro_instance) and not _intro_conversation_finished:
			await get_tree().process_frame

		if PORTAL_DEBUG:
			print_rich("[color=magenta][PORTAL DEBUG] intro conversation finished at %d ms[/color]" % Time.get_ticks_msec())

	# the wake CG outlives the conversation UNLESS the dialogue already faded it out itself
	# (chapter 2 does: the sprite scene plays over the level). if it is still up, let the
	# reveal land and fade it here; if it is already invisible, just free it. the layer is
	# kept alive through the sprite scene on purpose — its full-rect MOUSE_FILTER_STOP
	# backdrop swallows stray clicks to the level underneath.
	if is_instance_valid(wake_layer):
		if wake_layer.has_method("wait_for_pan"):
			await wake_layer.wait_for_pan()
		var wake_already_faded: bool = wake_layer.has_method("is_faded_out") and wake_layer.is_faded_out()
		if not wake_already_faded:
			await get_tree().create_timer(0.5).timeout
			if wake_layer.has_method("fade_out"):
				await wake_layer.fade_out(0.7)
		wake_layer.queue_free()
		DebugVRAM.snapshot("launch: wake cg freed")

	if GameManager:
		GameManager.enter_chapter_state()

	DebugVRAM.snapshot("launch: chapter ready")
	DebugVRAM.report()

	_launching = false

func _abort_launch_revealing_world() -> void:
	active_chapter_name = ""
	if GameManager and is_instance_valid(GameManager.transition_layer):
		# fade and abort portal
		await GameManager.transition_layer.portal_fade_abort(0.4)
	
	if NotificationManager:
		NotificationManager.add_notification("The memory slips away... (chapter failed to load)")
	
	if SoundManager and SoundManager.has_method("resume_ambience"):
		SoundManager.resume_ambience(1.0)
	
	if GameManager:
		GameManager.enter_chapter_state()
	
	_launching = false
	
	# release all preloaded references
	_preloaded_dialogue_resource = null
	_preloaded_balloon_scene = null

# ****************[return trip: chapter -> hub -> memory box]
# mirrors launch() in reverse: swirl over the chapter, template monologue, swap back to the
# hub, restore the stashed hub state, reopen the memory box, clear the portal onto it.
func return_to_hub(monologue_title: String = "return_to_hub") -> void:
	if _launching:
		return
	_launching = true

	DebugVRAM.snapshot("return: start (in chapter)")

	# front-load everything before any visual change
	_preloaded_dialogue_resource = null
	_preloaded_balloon_scene = null
	if not monologue_title.strip_edges().is_empty():
		if ResourceLoader.exists("res://dialogue/chapter_launch.dialogue"):
			_preloaded_dialogue_resource = load("res://dialogue/chapter_launch.dialogue") as DialogueResource
		if ResourceLoader.exists("res://conversation/conversationballoon.tscn"):
			_preloaded_balloon_scene = load("res://conversation/conversationballoon.tscn") as PackedScene

	ResourceLoader.load_threaded_request(HUB_SCENE_PATH)

	# the swirl needs a texture to grow, and there is no drawer thumbnail on the way back:
	# swirl a full-frame screenshot of the chapter itself.
	var shot_tex: Texture2D = null
	var vp = get_viewport()
	if vp and vp.get_texture():
		var shot_img: Image = vp.get_texture().get_image()
		if shot_img:
			# the swirl does not need a native-res frame: on a 4K window a full grab is a
			# ~32 MB RGBA texture. 1080p-width detail is plenty under the warp.
			if shot_img.get_width() > 1920:
				var k := 1920.0 / float(shot_img.get_width())
				shot_img.resize(1920, int(round(shot_img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
			shot_tex = ImageTexture.create_from_image(shot_img)

	if GameManager and is_instance_valid(GameManager.transition_layer):
		await GameManager.transition_layer.portal_enter(shot_tex, Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size))
	shot_tex = null

	if GameManager and is_instance_valid(GameManager.transition_layer):
		await GameManager.transition_layer.play_portal_monologue(monologue_title, _preloaded_dialogue_resource, _preloaded_balloon_scene)
	_preloaded_dialogue_resource = null
	_preloaded_balloon_scene = null

	# poll the hub load, same pattern as launch
	var hub_packed: PackedScene = null
	var _wait_start := Time.get_ticks_msec()
	while true:
		var status = ResourceLoader.load_threaded_get_status(HUB_SCENE_PATH)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			hub_packed = ResourceLoader.load_threaded_get(HUB_SCENE_PATH)
			break
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("ChapterLaunchSequence: hub load failed (status %d)" % status)
			await _abort_return()
			return
		elif Time.get_ticks_msec() - _wait_start > 15000:
			push_error("ChapterLaunchSequence: hub load timed out.")
			await _abort_return()
			return
		await get_tree().process_frame

	if hub_packed == null:
		await _abort_return()
		return

	DebugVRAM.snapshot("return: hub loaded, before swap")

	# arm the stashed hub state BEFORE the hub instances, so its LSM registration applies
	# it through the existing _pending_* pipe in SaveManager.
	if SaveManager and SaveManager.has_method("queue_hub_state_restore"):
		SaveManager.queue_hub_state_restore()

	# the chapter level IS the current_scene on the way back, so this frees it.
	get_tree().change_scene_to_packed(hub_packed)
	hub_packed = null
	await get_tree().process_frame
	await get_tree().process_frame

	DebugVRAM.snapshot("return: after swap to hub")

	# rebind everything to the swapped scene: player group, current_game_scene, hover state.
	if GameManager:
		GameManager.enter_chapter_state()

	# put the player back where they were standing when they launched — right next to the
	# memory box — instead of the level's default spawn.
	if SaveManager and SaveManager.has_method("apply_stashed_player_position"):
		SaveManager.apply_stashed_player_position()

	# reopen the memory box under the flash, so the portal clears onto it. mirrors
	# OpenMemoryBoxAction minus the iris — the portal flash is our cover here.
	var box_instance: Node = null
	if ResourceLoader.exists("res://conversation/MemoryBoxOverlay.tscn"):
		var box_packed: PackedScene = load("res://conversation/MemoryBoxOverlay.tscn")
		if box_packed:
			if GameManager:
				GameManager.cancel_current_action(false)
				GameManager.persisting_verb_id = ""
				GameManager.enter_conversation_state()
			box_instance = box_packed.instantiate()
			get_tree().root.add_child(box_instance)
			await get_tree().process_frame

	DebugVRAM.snapshot("return: memory box reopened")

	if GameManager and is_instance_valid(GameManager.transition_layer):
		await GameManager.transition_layer.portal_exit()

	if is_instance_valid(box_instance) and box_instance.has_method("play_boot_sequence"):
		box_instance.play_boot_sequence()

	active_chapter_name = ""
	DebugVRAM.snapshot("return: done")
	DebugVRAM.report()

	_launching = false


func _abort_return() -> void:
	if GameManager and is_instance_valid(GameManager.transition_layer):
		# fade and abort portal
		await GameManager.transition_layer.portal_fade_abort(0.4)
	if NotificationManager:
		NotificationManager.add_notification("The way back blurs... (hub failed to load)")
	_preloaded_dialogue_resource = null
	_preloaded_balloon_scene = null
	_launching = false


func _on_intro_conversation_finished(_resource) -> void:
	_intro_conversation_finished = true
