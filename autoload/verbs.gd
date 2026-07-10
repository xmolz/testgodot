extends Node

signal available_verbs_changed(available_verb_data_array: Array[VerbData])

var all_verb_data_resources: Array[VerbData] = []
var unlocked_verb_ids: Array[String] = []
var active_scene_verb_ids: Array[String] = []

func setup(verb_resources: Array[VerbData]):
	all_verb_data_resources = verb_resources.duplicate()
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.unlocked_by_default and not verb_data_res.verb_id in unlocked_verb_ids:
			unlocked_verb_ids.append(verb_data_res.verb_id)
	active_scene_verb_ids = unlocked_verb_ids.duplicate()
	_emit_available_verbs_changed_update()

func reset_run_state():
	unlocked_verb_ids.clear()
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.unlocked_by_default and not verb_data_res.verb_id in unlocked_verb_ids:
			unlocked_verb_ids.append(verb_data_res.verb_id)
	active_scene_verb_ids = unlocked_verb_ids.duplicate()
	_emit_available_verbs_changed_update()

func get_verb_data_by_id(verb_id_to_find: String) -> VerbData:
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.verb_id == verb_id_to_find:
			return verb_data_res
	return null

func get_currently_displayable_verbs() -> Array[VerbData]:
	var displayable_verbs: Array[VerbData] = []
	for verb_data_res in all_verb_data_resources:
		if verb_data_res and verb_data_res.verb_id in unlocked_verb_ids:
			if active_scene_verb_ids.is_empty() or verb_data_res.verb_id in active_scene_verb_ids:
				displayable_verbs.append(verb_data_res)
	return displayable_verbs

func _emit_available_verbs_changed_update():
	available_verbs_changed.emit(get_currently_displayable_verbs())

func set_active_scene_verbs(verb_ids_for_scene: Array[String]):
	active_scene_verb_ids = verb_ids_for_scene.duplicate()
	_emit_available_verbs_changed_update()

func unlock_verb(verb_id_to_unlock: String):
	var verb_data = get_verb_data_by_id(verb_id_to_unlock)
	if verb_data and not verb_id_to_unlock in unlocked_verb_ids:
		unlocked_verb_ids.append(verb_id_to_unlock)

		if not active_scene_verb_ids.is_empty() and not verb_id_to_unlock in active_scene_verb_ids:
			active_scene_verb_ids.append(verb_id_to_unlock)

		_emit_available_verbs_changed_update()
	elif not verb_data: print_rich("[color=red]GM: Tried to unlock non-existent verb: '%s'[/color]" % verb_id_to_unlock)
	elif verb_id_to_unlock in unlocked_verb_ids: print_rich("[color=yellow]GM: Verb '%s' already unlocked.[/color]" % verb_id_to_unlock)

func lock_verb(verb_id_to_lock: String):
	if verb_id_to_lock in unlocked_verb_ids:
		unlocked_verb_ids.erase(verb_id_to_lock)

		if verb_id_to_lock in active_scene_verb_ids:
			active_scene_verb_ids.erase(verb_id_to_lock)

		_emit_available_verbs_changed_update()
	else: print_rich("[color=orange]GM: Tried to lock verb '%s' that was not unlocked or doesn't exist.[/color]" % verb_id_to_lock)

func is_verb_id_currently_active(verb_id_to_check: String) -> bool:
	if not verb_id_to_check in unlocked_verb_ids: return false
	if active_scene_verb_ids.is_empty(): return true
	return active_scene_verb_ids.has(verb_id_to_check)
