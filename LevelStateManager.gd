# levelstatemanager.gd
extends Node
class_name LevelStateManager

signal level_flag_changed(flag_name: String, new_value: bool)
signal level_state_restored

@export var level_id: String = ""

# all level flags stored in
# just call set_level_flag("my_new_flag", true) from
var _flags: Dictionary = {}
var has_restored: bool = false

# default flag values for this
# note: flags in _defaults without
# aida_in_main_room
var _defaults: Dictionary = {
	"aida_in_main_room": true
}

# step 2.423: the hub flags "start where the demo ended" sets (see _ready)
const DEMO_END_FLAGS: Array[String] = [
	"has_spoken_to_aida",
	"aida_explanation_shown",
	"insurance_button_unlocked",
	"has_tried_memory_box",
]

@export_group("Debug Flag Toggles")
@export var override_has_spoken_to_aida: bool = false
@export var override_aida_explanation_shown: bool = false
@export var override_insurance_button_unlocked: bool = false
@export var override_has_tried_memory_box: bool = false
@export var override_mcbucket_interruption_happened: bool = false
@export var override_mcbucket_has_screamed_at_player: bool = false
@export var override_mcbucket_zanopram_used: bool = false
@export var override_mcbucket_cannathink_used: bool = false
@export var override_mcbucket_invigirol_used: bool = false
@export var override_toilet_has_paper: bool = false
@export var override_toilet_clogged: bool = false
@export var override_tv_examined: bool = false
@export var override_tv_turned_off: bool = false
@export var override_learned_techpass_from_aida: bool = false
@export var override_learned_techpass_from_sergey: bool = false
@export var override_give_techpass: bool = false
@export var override_dev_cta_completed: bool = false

# step 2.308: memory box testing (Main only). both are for this session only and never go into a save.
@export_group("Memory Box Test")
## the memory box as on a first visit: only Keeping Busy open. choosing a chapter plays a quick portal
## swirl and counts it as finished instead of playing it, so the chapter it unlocks lights up as new.
## also lets the memory box be used straight away (as if aiDA had already been talked to).
@export var test_memory_box_first_visit: bool = false
## every chapter and location open (no "new" glow), e.g. to play a chapter that is normally still locked
@export var unlock_all_chapters: bool = false


func _ready():
	for key in _defaults:
		_flags[key] = _defaults[key]

	# apply individual debug toggles (only
	var _toggles := {
		"has_spoken_to_aida": override_has_spoken_to_aida,
		"aida_explanation_shown": override_aida_explanation_shown,
		"insurance_button_unlocked": override_insurance_button_unlocked,
		"has_tried_memory_box": override_has_tried_memory_box,
		"mcbucket_interruption_happened": override_mcbucket_interruption_happened,
		"mcbucket_has_screamed_at_player": override_mcbucket_has_screamed_at_player,
		"mcbucket_zanopram_used": override_mcbucket_zanopram_used,
		"mcbucket_cannathink_used": override_mcbucket_cannathink_used,
		"mcbucket_invigirol_used": override_mcbucket_invigirol_used,
		"toilet_has_paper": override_toilet_has_paper,
		"toilet_clogged": override_toilet_clogged,
		"tv_examined": override_tv_examined,
		"tv_turned_off": override_tv_turned_off,
		"learned_techpass_from_aida": override_learned_techpass_from_aida,
		"learned_techpass_from_sergey": override_learned_techpass_from_sergey,
		"dev_cta_completed": override_dev_cta_completed,
	}
	for flag_name in _toggles:
		if _toggles[flag_name]:
			_flags[flag_name] = true

	# debug: give techpass item directly
	if override_give_techpass and GameManager:
		Inventory.add_item("techpass")

	# step 2.423: "start where the demo ended" (GameManager._ask_start_point): the hub as the first release left
	# it, the same five things the override toggles above do. applied once, on the hub's first instance of the
	# run, so a hub rebuilt on the way back from a chapter (or by a load) doesn't hand out a second pass.
	if level_id == "hospital_hub" and Engine.get_meta("start_at_demo_end", false):
		Engine.set_meta("start_at_demo_end", false)
		for flag_name in DEMO_END_FLAGS:
			_flags[flag_name] = true
		if GameManager and not Inventory.has_item("techpass"):
			Inventory.add_item("techpass")
		print_rich("[color=cyan]LevelStateManager: starting where the demo ended.[/color]")

	# step 2.308: memory box test toggles
	_apply_memory_box_test()

	print_rich("[color=LawnGreen]LevelStateManager for '%s' is ready.[/color]" % (get_parent().name if get_parent() else "UnnamedLevel"))


# step 2.308: the memory box test toggles. the "first visit" reset clears every chapter_ game flag (finished,
# unlocked, seen) once per session, so coming back to the hub from a chapter doesn't wipe it again.
func _apply_memory_box_test() -> void:
	# only ever switched on (other levels' managers leave them alone); a new run starts with them off
	if unlock_all_chapters:
		Engine.set_meta("dev_unlock_all_chapters", true)
	if not test_memory_box_first_visit:
		return
	Engine.set_meta("dev_quick_chapters", true)
	_flags["has_spoken_to_aida"] = true
	if Engine.get_meta("memory_box_test_reset_done", false):
		return
	Engine.set_meta("memory_box_test_reset_done", true)
	for key in Flags.game_flags.keys():
		if String(key).begins_with("chapter_"):
			Flags.game_flags.erase(key)
	print_rich("[color=cyan]LevelStateManager: memory box test on - first visit, only Keeping Busy open.[/color]")


func print_initial_flags():
	for flag_name in _flags:
		print_rich("  [color=gray]Initial Flag '%s': %s[/color]" % [flag_name, _flags[flag_name]])


func set_level_flag(flag_name: String, value: bool):
	if _flags.get(flag_name, false) == value:
		return

	_flags[flag_name] = value
	print_rich("[color=LawnGreen]LevelStateManager ('%s'): Level Flag Set -> %s = %s[/color]" % [get_parent().name if get_parent() else "", flag_name, value])
	level_flag_changed.emit(flag_name, value)


func get_level_flag(flag_name: String) -> bool:
	return _flags.get(flag_name, false)

func get_all_flags() -> Dictionary:
	return _flags.duplicate()

# writes a saved flag dict wholesale. bypasses set_level_flag()'s
# unchanged-value early return on purpose: a saved `false` landing on a
# default `false` still has to notify, because a listener's correct visual
# for `false` is not necessarily what it hardcoded in _ready().
func apply_saved_flags(saved: Dictionary) -> void:
	for flag_name in saved:
		var value: bool = bool(saved[flag_name])
		_flags[flag_name] = value
		level_flag_changed.emit(flag_name, value)
	has_restored = true
	level_state_restored.emit()
