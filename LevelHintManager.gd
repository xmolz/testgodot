extends Node
class_name LevelHintManager

@export var hints_dialogue: DialogueResource
@export var hints_adventure_dialogue: DialogueResource

func evaluate_hint() -> String:
	if not GameManager: return ""

	var needs_meds = GameManager.get_current_level_flag("mcbucket_interruption_happened")
	var in_bathroom = is_instance_valid(GameManager.player_node) and GameManager.player_node.global_position.y > 1000.0

	var has_any_drug = GameManager.has_item("zanopram") or GameManager.has_item("cannathink") or GameManager.has_item("invigirol")
	var used_any_drug = GameManager.get_current_level_flag("mcbucket_zanopram_used") or GameManager.get_current_level_flag("mcbucket_cannathink_used") or GameManager.get_current_level_flag("mcbucket_invigirol_used")
	var cabinet_raided = has_any_drug or used_any_drug

	# ==========================================
	# THE ACTION CHAIN (Physical Puzzles)
	# ==========================================
	if GameManager.has_item("techpass"):
		return "hint_has_techpass"

	if GameManager.get_current_level_flag("mcbucket_zanopram_used"):
		if needs_meds:
			return "hint_return_to_sergey"

	if GameManager.get_current_level_flag("mcbucket_cannathink_used") or GameManager.get_current_level_flag("mcbucket_invigirol_used"):
		if needs_meds: return "hint_wrong_drugs"
		else: return "hint_wrong_drugs_no_context"

	if GameManager.has_item("zanopram"):
		if needs_meds: return "hint_use_zanopram"
		else: return "hint_use_zanopram_no_context"

	if not GameManager.get_current_level_flag("aida_in_main_room") and not cabinet_raided:
		if needs_meds: return "hint_aida_gone"
		else: return "hint_aida_gone_no_context"

	if GameManager.get_current_level_flag("aida_in_main_room") and not cabinet_raided:
		if GameManager.get_current_level_flag("toilet_clogged"):
			if needs_meds: return "hint_toilet_clogged"
			else: return "hint_toilet_clogged_no_context"

		if needs_meds and GameManager.get_current_level_flag("aida_stopped_cabinet"):
			if in_bathroom: return "hint_clog_toilet_bathroom"
			else: return "hint_clog_toilet_main"

	# ==========================================
	# THE CONTEXT CHAIN (Story Objectives)
	# ==========================================
	if needs_meds:
		return "hint_need_distraction"

	if GameManager.get_current_level_flag("has_tried_memory_box"):
		return "hint_ask_sergey"

	if GameManager.get_current_level_flag("has_spoken_to_aida"):
		return "hint_use_memory_box"

	return "hint_start"
