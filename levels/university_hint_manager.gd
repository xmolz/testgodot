extends LevelHintManager
## step 2.358: the think verb's hints for the university level (Keeping Busy). like the hospital's
## LevelHintManager: checks the latest stage first, so playing out of order still gets the right hint.
## returns "" where there is deliberately no hint (think then does nothing).
## titles live in dialogue/hints_university_adventure.dialogue.

## Professor Greene's office is the area right of the supply room, on the 2F strip.
const GREENE_OFFICE_MIN_X := 13000.0
const GREENE_OFFICE_MAX_Y := 1200.0


func evaluate_hint() -> String:
	if not GameManager:
		return ""
	# the code worked: they go straight into the lab
	if Flags.get_level_flag("lab_entry_ready"):
		return ""
	# after the janitor hands over the keycard (or leaves)
	if Flags.get_level_flag("greene_office_unlocked"):
		return "hint_in_office" if _in_greene_office() else "hint_office_open"
	# the keycard
	if Flags.get_level_flag("greene_office_keycard_talk_seen"):
		if Inventory.has_item("jayce_camera"):
			return "hint_use_camera"
		if Flags.get_level_flag("jayce_keycard_refused"):
			return "hint_find_leverage"
		return "hint_get_keycard"
	# the DNA date failed and the faculty floor opened
	if Flags.get_level_flag("faculty_floor_unlocked"):
		return "hint_go_to_office"
	# the dates are found: no hint until they've tried them
	if Flags.get_level_flag("dna_dates_found"):
		return ""
	# Julian's lead
	if Flags.get_level_flag("dna_dates_lookup_pending"):
		if Inventory.has_item("layla_phone") and not Flags.get_level_flag("layla_phone_charged"):
			return "hint_charge_phone"
		return "hint_dna_lookup"
	# the code
	if Flags.get_level_flag("jayce_date_hint_given"):
		if Flags.get_level_flag("keypad_date_tried"):
			return "hint_after_first_date"
		return "hint_try_date"
	if Flags.get_level_flag("lab_keypad_interacted"):
		return "hint_keypad_locked"
	return "hint_start"


func _in_greene_office() -> bool:
	var player = GameManager.player_node
	if not is_instance_valid(player):
		return false
	return player.global_position.x > GREENE_OFFICE_MIN_X and player.global_position.y < GREENE_OFFICE_MAX_Y
