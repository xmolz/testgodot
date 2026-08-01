extends Control

@onready var level_state_manager: LevelStateManager = $LevelStateManager

func _ready():
	await get_tree().process_frame
	if GameManager:
		if is_instance_valid(level_state_manager):
			Flags.register_level_state_manager(level_state_manager)
		
		# Unlock basic verbs so the UI doesn't break
		var all_verbs: Array[String] = ["examine", "talk_to", "pickup", "use", "give", "flash", "think"]
		for v in all_verbs:
			Verbs.unlock_verb(v)
		Verbs.set_active_scene_verbs(all_verbs)

func _exit_tree():
	if GameManager and is_instance_valid(level_state_manager):
		if Flags.current_level_state_manager == level_state_manager:
			Flags.register_level_state_manager(null)
			GameManager.current_hint_manager = null
