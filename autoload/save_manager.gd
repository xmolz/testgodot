extends Node

const SAVE_VERSION := 2
const SAVE_DIR := "user://Lewgend/If I Remember Correctly/"
const AUTOSAVE_PATH := "user://Lewgend/If I Remember Correctly/autosave.json"
const AUTOSAVE_BACKUP_PATH := "user://Lewgend/If I Remember Correctly/autosave.json.bak"
const HUB_LEVEL_ID := "hospital_hub"

signal save_completed(slot: String)
signal load_completed(slot: String)
signal load_failed(reason: String)

var is_loading: bool = false

# thumbnail size written next to each slot json. 16:9, small enough that four slots on the
# load screen cost nothing.
const SCREENSHOT_THUMB_SIZE := Vector2i(480, 270)

# the downscaled world frame captured when the pause menu opened. written to disk by
# save_to_slot(); refreshed on every pause open.
var pending_screenshot: Image = null
var _playtime_seconds: float = 0.0
var _last_known_hub_flags: Dictionary = {}
var _active_dialogue_depth: int = 0

var _pending_level_flags: Dictionary = {}
var _pending_level_id: String = ""
var _pending_npcs_state: Dictionary = {}
var _level_state_ready_emitted: bool = false

# hub state stashed by the chapter launch pipeline right before the hub scene is freed,
# and restored when the hub is re-instanced on the way back. level flags and npc positions
# live in scene nodes, not autoloads, so a hub round trip would otherwise reset them.
var _stashed_hub_flags: Dictionary = {}
var _stashed_hub_npcs: Dictionary = {}
var has_stashed_hub_state: bool = false
var _stashed_player_pos: Vector2 = Vector2.ZERO
var _stashed_player_flip: bool = false
var _has_stashed_player: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if DialogueManager:
		DialogueManager.dialogue_started.connect(_on_dialogue_started)
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
		
	if Flags:
		Flags.level_state_manager_registered.connect(_on_level_state_manager_registered)

func _process(delta: float):
	if GameManager and GameManager.current_game_state == GameManager.GameState.IN_GAME_PLAY:
		_playtime_seconds += delta

func _on_dialogue_started(_resource):
	_active_dialogue_depth += 1

func _on_dialogue_ended(_resource):
	_active_dialogue_depth -= 1
	if _active_dialogue_depth < 0:
		_active_dialogue_depth = 0

func reset_transient_state() -> void:
	_active_dialogue_depth = 0

func _on_level_state_manager_registered(lsm: LevelStateManager):
	_level_state_ready_emitted = false
	if not is_instance_valid(lsm): return
	
	if lsm.level_id == _pending_level_id and not _pending_level_id.is_empty():
		lsm.apply_saved_flags(_pending_level_flags)
		_apply_npcs(_pending_npcs_state)
		_pending_level_flags.clear()
		_pending_npcs_state.clear()
		_pending_level_id = ""

	if lsm.level_id == HUB_LEVEL_ID:
		_last_known_hub_flags = lsm.get_all_flags()

	if Events and Events.has_signal("level_state_ready") and not _level_state_ready_emitted:
		_level_state_ready_emitted = true
		Events.level_state_ready.emit.call_deferred()

# called by ChapterLaunchSequence right before the hub is freed for a chapter.
func stash_hub_state() -> void:
	var lsm = Flags.current_level_state_manager
	if is_instance_valid(lsm) and lsm.level_id == HUB_LEVEL_ID:
		_stashed_hub_flags = lsm.get_all_flags().duplicate()
		_last_known_hub_flags = _stashed_hub_flags.duplicate()
		_stashed_hub_npcs = _collect_npcs()
		has_stashed_hub_state = true

	# also remember where the player was standing — right next to the memory box, since
	# they just used it — so the return trip does not dump them at the default spawn.
	if GameManager and is_instance_valid(GameManager.player_node):
		_stashed_player_pos = GameManager.player_node.global_position
		_stashed_player_flip = false
		if is_instance_valid(GameManager.player_node.sprite_2d):
			_stashed_player_flip = GameManager.player_node.sprite_2d.flip_h
		_has_stashed_player = true

# called by ChapterLaunchSequence right before the hub scene re-instances on the way back.
# the restore itself rides the existing _pending_* pipe: when the hub's LevelStateManager
# registers, _on_level_state_manager_registered applies flags and npc state.
func queue_hub_state_restore() -> void:
	if not has_stashed_hub_state:
		return
	_pending_level_id = HUB_LEVEL_ID
	_pending_level_flags = _stashed_hub_flags.duplicate()
	_pending_npcs_state = _stashed_hub_npcs.duplicate()
	has_stashed_hub_state = false

# called by the return pipeline after the hub is re-instanced and the player node
# re-found. mirrors the load_from_slot() player restore, camera snap included.
func apply_stashed_player_position() -> void:
	if not _has_stashed_player:
		return
	_has_stashed_player = false
	if not (GameManager and is_instance_valid(GameManager.player_node)):
		return
	GameManager.player_node.global_position = _stashed_player_pos
	if is_instance_valid(GameManager.player_node.sprite_2d):
		GameManager.player_node.sprite_2d.flip_h = _stashed_player_flip
	var camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera) and camera.has_method("snap_to_target"):
		camera.snap_to_target()

func can_save_now(allow_pause_snapshot: bool = false) -> bool:
	if not GameManager: return false
	
	var effective_state = GameManager.current_game_state
	if allow_pause_snapshot and is_instance_valid(GameManager.pause_menu_ui):
		effective_state = GameManager.pause_menu_ui.get_effective_game_state()
		
	if effective_state != GameManager.GameState.IN_GAME_PLAY: return false
	if GameManager.current_interaction_state != GameManager.InteractionState.WORLD: return false
	if GameManager.is_transitioning: return false
	if GameManager.is_verb_lock_active: return false
	if GameManager.get("_is_game_over_triggering") == true: return false
	if _active_dialogue_depth > 0: return false
	if not allow_pause_snapshot and get_tree().paused: return false
	
	if ChapterLaunchSequence and ChapterLaunchSequence.is_launching(): return false
	if GameManager and GameManager.is_cutscene_sequence_running(): return false
	if is_loading: return false
	if not is_instance_valid(Flags.current_level_state_manager): return false

	return true

func has_save(slot: String) -> bool:
	var path = _get_slot_path(slot)
	return FileAccess.file_exists(path)

func read_meta(slot: String) -> Dictionary:
	var path = _get_slot_path(slot)
	if not FileAccess.file_exists(path): return {}
	
	var data = _read_json(path)
	if data == null or not (data is Dictionary): return {}
	if not data.has("meta") or not (data["meta"] is Dictionary): return {}
	
	return data["meta"]

func delete_slot(slot: String) -> bool:
	var path = _get_slot_path(slot)
	if FileAccess.file_exists(path):
		var da = DirAccess.open(SAVE_DIR)
		if da:
			da.remove(path.get_file())
			var shot = get_slot_screenshot_path(slot)
			if da.file_exists(shot.get_file()):
				da.remove(shot.get_file())
			return true
	return false

# ---- Save slot screenshots ----

# grabs the last presented frame and keeps a small thumbnail in memory. must be called
# BEFORE any menu ui draws — the pause menu calls it as it opens — so the thumbnail shows
# the game world and not the pause overlay.
func capture_world_screenshot() -> void:
	var vp = get_viewport()
	if vp == null: return
	var tex = vp.get_texture()
	if tex == null: return
	var img: Image = tex.get_image()
	if img == null: return
	img.resize(SCREENSHOT_THUMB_SIZE.x, SCREENSHOT_THUMB_SIZE.y, Image.INTERPOLATE_BILINEAR)
	pending_screenshot = img

func get_slot_screenshot_path(slot: String) -> String:
	return _get_slot_path(slot).get_basename() + ".png"

# writes the pending thumbnail next to the slot json. if there is no pending screenshot,
# removes any stale one so a slot never shows a thumbnail from an older save.
func _write_slot_screenshot(slot: String) -> void:
	var shot_path = get_slot_screenshot_path(slot)
	if pending_screenshot != null:
		var err = pending_screenshot.save_png(shot_path)
		if err != OK:
			push_warning("SaveManager: could not write screenshot %s (err %d)" % [shot_path, err])
	elif FileAccess.file_exists(shot_path):
		var da = DirAccess.open(SAVE_DIR)
		if da:
			da.remove(shot_path.get_file())

func _get_slot_path(slot: String) -> String:
	if slot == "autosave":
		return AUTOSAVE_PATH
	return SAVE_DIR + slot + ".json"

func get_most_recent_slot() -> String:
	var most_recent_slot = ""
	var max_timestamp = 0.0
	
	var slots = ["autosave", "slot_1", "slot_2", "slot_3"]
	for slot in slots:
		var meta = read_meta(slot)
		if meta and meta.has("timestamp_unix"):
			var ts = float(meta["timestamp_unix"])
			if ts > max_timestamp:
				max_timestamp = ts
				most_recent_slot = slot
	
	return most_recent_slot

func _write_json_atomic(path: String, payload: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
			
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open %s (err %d)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.flush()
	f.close()                                  # MUST close before rename (Windows lock)
	var da := DirAccess.open(SAVE_DIR)
	if da == null:
		return false
	if da.file_exists(path.get_file()):
		# defensive: some platforms refuse rename-over-existing
		var err_pre := da.rename(tmp.get_file(), path.get_file())
		if err_pre == OK:
			return true
		da.remove(path.get_file())
	return da.rename(tmp.get_file(), path.get_file()) == OK

func _read_json(path: String):
	var f = FileAccess.open(path, FileAccess.READ)
	if not f: return null
	var content = f.get_as_text()
	f.close()
	return JSON.parse_string(content)

func save_to_slot(slot: String) -> bool:
	var lsm = Flags.current_level_state_manager
	var in_hub: bool = is_instance_valid(lsm) and lsm.level_id == HUB_LEVEL_ID

	var location_label = "Hospital Room"
	var scene_path_for_save = "res://main.tscn"
	var chapter_id = ""
	if not in_hub:
		location_label = "Memory"
		if ChapterLaunchSequence and not ChapterLaunchSequence.active_chapter_name.is_empty():
			location_label = "Memory: " + ChapterLaunchSequence.active_chapter_name
		var cs = get_tree().current_scene
		if is_instance_valid(cs) and not cs.scene_file_path.is_empty():
			scene_path_for_save = cs.scene_file_path
		if is_instance_valid(lsm):
			chapter_id = lsm.level_id

	var payload = {
		"version": SAVE_VERSION,
		"meta": {
			"timestamp_unix": Time.get_unix_time_from_system(),
			"chapters_completed": 0, # TODO(save-step-N)
			"clues_found": 0, # TODO(save-step-N)
			"clues_total_known": 0, # TODO(save-step-N)
			"form_fields_locked": 0, # TODO(save-step-N)
			"playtime_seconds": _playtime_seconds,
			"location_label": location_label
		},
		"location": {
			"is_in_hub": in_hub,
			"current_scene_path": scene_path_for_save,
			"chapter_id_if_memory": chapter_id,
			"is_replay": false,
			"player_x": 0.0,
			"player_y": 0.0,
			"player_flip_h": false
		},
		"flags": { "game_flags": _collect_flags() },
		"hub_level_flags": lsm.get_all_flags() if in_hub else _last_known_hub_flags,
		"memory_level_flags": lsm.get_all_flags() if (not in_hub and is_instance_valid(lsm)) else {},
		"inventory": { "item_ids": _collect_inventory() },
		"verbs": { "unlocked_verb_ids": _collect_verbs() },
		"dialogue": { "visited_responses": _collect_dialogue_history() },
		"conversation_events": _collect_conversation_events(),
		"clues": { "found": {} }, # TODO(save-step-N)
		"chapters": { "records": {}, "in_progress": {} }, # TODO(save-step-N)
		"form": { "locked_fields": {} }, # TODO(save-step-N)
		"difficulty": { "assisted_mode": Settings.assisted_mode },
		"npcs": _collect_npcs(),
		"hub_stash": {
			"npcs": _stashed_hub_npcs,
			"player_x": _stashed_player_pos.x,
			"player_y": _stashed_player_pos.y,
			"player_flip_h": _stashed_player_flip,
			"has_player": _has_stashed_player
		}
	}
	
	if is_instance_valid(GameManager.player_node):
		payload["location"]["player_x"] = GameManager.player_node.global_position.x
		payload["location"]["player_y"] = GameManager.player_node.global_position.y
		if is_instance_valid(GameManager.player_node.sprite_2d):
			payload["location"]["player_flip_h"] = GameManager.player_node.sprite_2d.flip_h

	var path = _get_slot_path(slot)
	var success = _write_json_atomic(path, payload)
	if success:
		_write_slot_screenshot(slot)
		save_completed.emit(slot)
	return success

func load_from_slot(slot: String) -> bool:
	var path = _get_slot_path(slot)
	if not FileAccess.file_exists(path):
		NotificationManager.add_notification("Save file not found.")
		load_failed.emit("file not found")
		return false
		
	var data = _read_json(path)
	if data == null or not (data is Dictionary):
		NotificationManager.add_notification("Failed to read save file. The file is corrupt.")
		load_failed.emit("parse error or not a dictionary")
		return false
		
	if not data.has("version"):
		NotificationManager.add_notification("Save file is invalid (no version).")
		load_failed.emit("no version")
		return false
		
	var version = int(data["version"])
	if version > SAVE_VERSION:
		NotificationManager.add_notification("Save file is from a newer version of the game.")
		load_failed.emit("version too new")
		return false
		
	if version < SAVE_VERSION:
		data = _migrate_save_data(data, version)
		
	var required_sections = ["meta", "location", "flags", "hub_level_flags", "inventory", "verbs", "dialogue", "conversation_events", "difficulty", "npcs"]
	for sec in required_sections:
		if not data.has(sec) or not (data[sec] is Dictionary):
			NotificationManager.add_notification("Save file is corrupted (missing section).")
			load_failed.emit("missing section: " + sec)
			return false
			
	var loc_data = data["location"]
	var is_hub_save: bool = bool(loc_data.get("is_in_hub", true))
		
	var scene_path = loc_data.get("current_scene_path", "")
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		NotificationManager.add_notification("Save file scene is missing or invalid.")
		load_failed.emit("invalid scene path")
		return false

	is_loading = true
	
	if GameManager.transition_layer and GameManager.transition_layer.has_method("show_loading_indicator"):
		GameManager.transition_layer.show_loading_indicator()
		
	if GameManager.transition_layer and GameManager.transition_layer.has_method("global_fade_to_black"):
		await GameManager.transition_layer.global_fade_to_black(0.5)
		
	if SceneDirector and SceneDirector.has_method("teardown_game_scene"):
		SceneDirector.teardown_game_scene()
		
	GameManager.reset_run_state()
	
	_apply_flags(data["flags"]["game_flags"])
	_apply_inventory(data["inventory"]["item_ids"])
	_apply_verbs(data["verbs"]["unlocked_verb_ids"])
	_apply_dialogue_history(data["dialogue"]["visited_responses"])
	_apply_conversation_events(data["conversation_events"])
	Settings.assisted_mode = bool(data["difficulty"].get("assisted_mode", false))
	_playtime_seconds = float(data["meta"].get("playtime_seconds", 0.0))
	
	if is_hub_save:
		_pending_level_id = HUB_LEVEL_ID
		_pending_level_flags = data["hub_level_flags"].duplicate()
		_pending_npcs_state = data["npcs"].duplicate()
		
		await GameManager.change_game_state(GameManager.GameState.IN_GAME_PLAY)
	else:
		# memory save: land straight in the chapter scene. no portal, no intro sequence —
		# the developer chose "resume exactly where I was".
		_pending_level_id = String(loc_data.get("chapter_id_if_memory", ""))
		_pending_level_flags = data.get("memory_level_flags", {}).duplicate()
		_pending_npcs_state = data["npcs"].duplicate()

		# re-arm the hub stash from the save, so the Return trip after this load restores
		# the hub exactly as it was left when the chapter was launched.
		var hub_stash = data.get("hub_stash", {})
		_stashed_hub_flags = data["hub_level_flags"].duplicate()
		_last_known_hub_flags = _stashed_hub_flags.duplicate()
		_stashed_hub_npcs = hub_stash.get("npcs", {}).duplicate()
		has_stashed_hub_state = true
		_stashed_player_pos = Vector2(float(hub_stash.get("player_x", 0.0)), float(hub_stash.get("player_y", 0.0)))
		_stashed_player_flip = bool(hub_stash.get("player_flip_h", false))
		_has_stashed_player = bool(hub_stash.get("has_player", false))

		var chapter_packed: PackedScene = load(scene_path)
		if chapter_packed == null:
			is_loading = false
			if GameManager.transition_layer and GameManager.transition_layer.has_method("hide_loading_indicator"):
				await GameManager.transition_layer.hide_loading_indicator()
			if GameManager.transition_layer and GameManager.transition_layer.has_method("global_fade_from_black"):
				GameManager.transition_layer.global_fade_from_black(0.5)
			NotificationManager.add_notification("Failed to load save: chapter scene could not be loaded.")
			load_failed.emit("chapter scene load failed")
			GameManager.change_game_state(GameManager.GameState.MAIN_MENU)
			return false

		get_tree().change_scene_to_packed(chapter_packed)
		await get_tree().process_frame
		await get_tree().process_frame

		# point SceneDirector at the chapter BEFORE the state change, so ensure_game_scene()
		# does not also build the hub underneath it.
		SceneDirector.current_game_scene = get_tree().current_scene

		await GameManager.change_game_state(GameManager.GameState.IN_GAME_PLAY)

		if GameManager:
			GameManager.enter_chapter_state()
	
	# After scene loaded, wait for lsm to register and flags to be applied
	var watchdog_frames = 600
	while _pending_level_id != "":
		await get_tree().process_frame
		watchdog_frames -= 1
		if watchdog_frames <= 0:
			_pending_level_id = ""
			_pending_level_flags.clear()
			_pending_npcs_state.clear()
			is_loading = false
			if GameManager.transition_layer and GameManager.transition_layer.has_method("hide_loading_indicator"):
				await GameManager.transition_layer.hide_loading_indicator()
			if GameManager.transition_layer and GameManager.transition_layer.has_method("global_fade_from_black"):
				GameManager.transition_layer.global_fade_from_black(0.5)
			NotificationManager.add_notification("Failed to load save: level root never registered state manager.")
			load_failed.emit("level never registered")
			GameManager.change_game_state(GameManager.GameState.MAIN_MENU)
			return false
		
	if is_instance_valid(GameManager.player_node):
		if GameManager.player_node.has_method("set_can_move"):
			GameManager.player_node.set_can_move(false)
		GameManager.player_node.global_position = Vector2(float(loc_data.get("player_x", 0)), float(loc_data.get("player_y", 0)))
		if is_instance_valid(GameManager.player_node.sprite_2d):
			GameManager.player_node.sprite_2d.flip_h = bool(loc_data.get("player_flip_h", false))
			
		var camera = get_viewport().get_camera_2d()
		if is_instance_valid(camera) and camera.has_method("snap_to_target"):
			camera.snap_to_target()
			
		if GameManager.player_node.has_method("set_can_move"):
			GameManager.player_node.set_can_move(true)
			
	GameManager.refresh_hint_system()
	
	is_loading = false
	if GameManager.transition_layer and GameManager.transition_layer.has_method("hide_loading_indicator"):
		await GameManager.transition_layer.hide_loading_indicator()
		
	if GameManager.transition_layer and GameManager.transition_layer.has_method("global_fade_from_black"):
		GameManager.transition_layer.global_fade_from_black(0.5)
		
	load_completed.emit(slot)
	return true

func _migrate_save_data(data: Dictionary, from_version: int) -> Dictionary:
	# v1 -> v2: every v1 save is a hub save by definition (is_in_hub was hardcoded true).
	# add the sections v2 reads; their content only matters for memory saves.
	if from_version < 2:
		if not data.has("hub_stash") or not (data["hub_stash"] is Dictionary):
			data["hub_stash"] = {}
		if not data.has("memory_level_flags") or not (data["memory_level_flags"] is Dictionary):
			data["memory_level_flags"] = {}
		data["version"] = 2
	return data

# ---- Private Data Collection & Application Helpers ----

# Note: Keeping serialization in SaveManager to avoid bloating existing autoloads

func _collect_flags() -> Dictionary:
	return Flags.game_flags.duplicate()

func _apply_flags(saved_flags: Dictionary):
	Flags.game_flags = saved_flags.duplicate()

func _collect_inventory() -> Array:
	var item_ids = []
	for item in Inventory.items:
		item_ids.append(item.item_id)
	return item_ids

func _apply_inventory(item_ids: Array):
	for id in item_ids:
		if id is String:
			Inventory.add_item(id)

func _collect_verbs() -> Array:
	return Verbs.unlocked_verb_ids.duplicate()

func _apply_verbs(verb_ids: Array):
	for id in verb_ids:
		if id is String:
			Verbs.unlock_verb(id)

func _collect_dialogue_history() -> Dictionary:
	return DialogueHistory.visited_responses.duplicate()

func _apply_dialogue_history(responses: Dictionary):
	# Note: DialogueHistory.entries is dropped (starts empty)
	DialogueHistory.visited_responses = responses.duplicate()

func _collect_conversation_events() -> Dictionary:
	return {
		"show_special_response": ConversationEventManager.show_special_response,
		"has_heard_fresh_start_line": ConversationEventManager.has_heard_fresh_start_line,
		"asked_sergey_duration": ConversationEventManager.asked_sergey_duration,
		"asked_sergey_identity": ConversationEventManager.asked_sergey_identity
	}

func _apply_conversation_events(data: Dictionary):
	ConversationEventManager.show_special_response = bool(data.get("show_special_response", false))
	ConversationEventManager.has_heard_fresh_start_line = bool(data.get("has_heard_fresh_start_line", false))
	ConversationEventManager.asked_sergey_duration = bool(data.get("asked_sergey_duration", false))
	ConversationEventManager.asked_sergey_identity = bool(data.get("asked_sergey_identity", false))

func _collect_npcs() -> Dictionary:
	var npcs_state = {}
	for npc in get_tree().get_nodes_in_group("saveable_npc"):
		if not is_instance_valid(npc): continue
		var state = {}
		state["pos_x"] = npc.global_position.x
		state["pos_y"] = npc.global_position.y
		
		var sprite = npc.get_node_or_null("Sprite")
		if not sprite: sprite = npc.get_node_or_null("ObjectSprite")
		if sprite: state["flip_h"] = sprite.flip_h
		
		var mover = npc.get_node_or_null("MovementController")
		if mover and mover.has_method("get_movement_state"):
			var mv_state = mover.get_movement_state()
			state["waypoint_index"] = mv_state.get("waypoint_index", 0)
			state["is_waiting"] = mv_state.get("is_waiting", false)
			state["ping_pong_direction"] = mv_state.get("ping_pong_direction", 1)
			state["movement_active"] = mv_state.get("movement_active", true)
			
		npcs_state[npc.name] = state
	return npcs_state

func _apply_npcs(dict: Dictionary):
	for npc in get_tree().get_nodes_in_group("saveable_npc"):
		if not is_instance_valid(npc) or not dict.has(npc.name): continue
		var state = dict[npc.name]
		
		npc.global_position = Vector2(float(state.get("pos_x", npc.global_position.x)), float(state.get("pos_y", npc.global_position.y)))
		
		var sprite = npc.get_node_or_null("Sprite")
		if not sprite: sprite = npc.get_node_or_null("ObjectSprite")
		if sprite and state.has("flip_h"):
			sprite.flip_h = bool(state["flip_h"])
			
		var mover = npc.get_node_or_null("MovementController")
		if mover and mover.has_method("apply_movement_state"):
			mover.apply_movement_state(state)

		# Explicitly recalculate and set the projected flag for Aida so it agrees with her restored position.
		if npc.name == "AIda":
			var is_currently_in_main = npc.global_position.y < 1000.0 # ROOM_THRESHOLD_Y from aida.gd
			npc.set("_was_in_main_room", is_currently_in_main)
			if Flags.current_level_state_manager:
				Flags.current_level_state_manager.set_level_flag("aida_in_main_room", is_currently_in_main)
