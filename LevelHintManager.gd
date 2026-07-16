extends Node
class_name LevelHintManager

@export var hints_dialogue: DialogueResource
@export var hints_adventure_dialogue: DialogueResource

func evaluate_hint() -> String:
	if not GameManager: return ""

	var needs_meds = Flags.get_level_flag("mcbucket_interruption_happened")
	var in_bathroom = is_instance_valid(GameManager.player_node) and GameManager.player_node.global_position.y > 1000.0

	var has_any_drug = Inventory.has_item("zanopram") or Inventory.has_item("cannathink") or Inventory.has_item("invigirol")
	var state_from_flash = Flags.get_level_flag("mcbucket_state_from_flash")
	var used_any_drug = (Flags.get_level_flag("mcbucket_zanopram_used") or Flags.get_level_flag("mcbucket_cannathink_used") or Flags.get_level_flag("mcbucket_invigirol_used")) and not state_from_flash
	var cabinet_raided = has_any_drug or used_any_drug

	# ==========================================
	# THE ACTION CHAIN (Physical Puzzles)
	# ==========================================
	if Inventory.has_item("techpass"):
		return "hint_has_techpass"

	if Flags.get_level_flag("mcbucket_zanopram_used"):
		if needs_meds:
			return "hint_return_to_sergey"

	if (Flags.get_level_flag("mcbucket_cannathink_used") or Flags.get_level_flag("mcbucket_invigirol_used")) and not state_from_flash:
		if needs_meds: return "hint_wrong_drugs"
		else: return "hint_wrong_drugs_no_context"

	if Inventory.has_item("zanopram"):
		if needs_meds: return "hint_use_zanopram"
		else: return "hint_use_zanopram_no_context"

	if not Flags.get_level_flag("aida_in_main_room") and not cabinet_raided:
		if needs_meds: return "hint_aida_gone"
		else: return "hint_aida_gone_no_context"

	if Flags.get_level_flag("aida_in_main_room") and not cabinet_raided:
		if Flags.get_level_flag("toilet_clogged"):
			if needs_meds: return "hint_toilet_clogged"
			else: return "hint_toilet_clogged_no_context"

		if needs_meds and Flags.get_level_flag("aida_stopped_cabinet"):
			if in_bathroom: return "hint_clog_toilet_bathroom"
			else: return "hint_clog_toilet_main"

	# ==========================================
	# THE CONTEXT CHAIN (Story Objectives)
	# ==========================================
	if needs_meds:
		return "hint_need_distraction"

	if Flags.get_level_flag("has_tried_memory_box"):
		return "hint_ask_sergey"

	if Flags.get_level_flag("has_spoken_to_aida"):
		return "hint_use_memory_box"

	return "hint_start"
