extends Control

@onready var level_state_manager = $LevelStateManager

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	if GameManager:
		Flags.register_level_state_manager(level_state_manager)

	await get_tree().process_frame
	await get_tree().process_frame

	if GameManager:
		var all_verbs: Array[String] = ["examine", "talk_to", "pickup", "use", "give", "flash", "think"]
		for v in all_verbs:
			Verbs.unlock_verb(v)
		Verbs.set_active_scene_verbs(all_verbs)

		Inventory.add_item("hospital_toilet_paper")

		level_state_manager.set_level_flag("insurance_button_unlocked", true)
		level_state_manager.set_level_flag("dev_cta_completed", false)

		# note: this mockup scene has
		# and the journal/insurance button presses
		var mock_insurance = get_node_or_null("%InsuranceFormButtonUI")
		if is_instance_valid(mock_insurance): mock_insurance.show()

		var mock_journal = get_node_or_null("%JournalButtonUI")
		if is_instance_valid(mock_journal): mock_journal.show()

		var mock_verb = get_node_or_null("%VerbUI_CanvasLayer")
		if is_instance_valid(mock_verb): mock_verb.show()

		var mock_inventory = get_node_or_null("%InventoryUI_CanvasLayer")
		if is_instance_valid(mock_inventory): mock_inventory.show()

		if is_instance_valid(GameManager.patreon_world_ui):
			GameManager.patreon_world_ui.hide()

		if is_instance_valid(GameManager.pause_menu_ui):
			GameManager.pause_menu_ui.menu_panel.show()
			GameManager.pause_menu_ui.set_cancel_mode(false)
