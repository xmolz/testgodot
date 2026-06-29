extends Control

@onready var level_state_manager = $LevelStateManager

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if GameManager:
		GameManager.register_level_state_manager(level_state_manager)

	await get_tree().process_frame
	await get_tree().process_frame

	if GameManager:
		var all_verbs: Array[String] = ["examine", "talk_to", "pickup", "use", "give", "flash", "think"]
		for v in all_verbs:
			GameManager.unlock_verb(v)
		GameManager.set_active_scene_verbs(all_verbs)

		GameManager.add_item_to_inventory("hospital_toilet_paper")

		level_state_manager.set_level_flag("insurance_button_unlocked", true)
		level_state_manager.set_level_flag("dev_cta_completed", false)

		if is_instance_valid(GameManager.insurance_form_button_ui):
			GameManager.insurance_form_button_ui.show()

		if is_instance_valid(GameManager.journal_button_ui):
			GameManager.journal_button_ui.show()

		if is_instance_valid(GameManager.verb_ui):
			GameManager.verb_ui.show()

		if is_instance_valid(GameManager.inventory_ui):
			GameManager.inventory_ui.show()

		if is_instance_valid(GameManager.patreon_world_ui):
			GameManager.patreon_world_ui.hide()

		if is_instance_valid(GameManager.pause_menu_ui):
			GameManager.pause_menu_ui.menu_panel.show()
			GameManager.pause_menu_ui.set_cancel_mode(false)
