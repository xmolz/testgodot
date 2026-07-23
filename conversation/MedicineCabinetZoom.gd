extends ObjectZoomOverlay

@export var caught_dialogue_resource: DialogueResource
@export var caught_dialogue_start_id: String = "aida_caught_snooping"

func _ready():
	super._ready()
	
	print_rich("[color=orange]MedicineCabinet: Zoom opened. Forcing Game Unpause to allow Aida to move.[/color]")
	get_tree().paused = false
	
	if GameManager and Flags.current_level_state_manager:
		if not Flags.current_level_state_manager.level_flag_changed.is_connected(_on_level_flag_changed):
			Flags.current_level_state_manager.level_flag_changed.connect(_on_level_flag_changed)

func _on_level_flag_changed(flag_name: String, new_value: bool):
	if flag_name == "aida_in_main_room" and new_value == true:
		print_rich("[color=red]MedicineCabinet: AIDA RETURNED! Triggering caught sequence.[/color]")
		_trigger_forced_exit()

func _trigger_forced_exit():
	# trigger the dialogue first, before we delete this node
	if caught_dialogue_resource:
		_start_caught_dialogue()

	_cleanup_and_queue_free()

func _cleanup_and_queue_free():
	# safely disconnect the level-flag signal
	if GameManager and Flags.current_level_state_manager:
		if Flags.current_level_state_manager.level_flag_changed.is_connected(_on_level_flag_changed):
			Flags.current_level_state_manager.level_flag_changed.disconnect(_on_level_flag_changed)
	super._cleanup_and_queue_free()

func _start_caught_dialogue():
	print_rich("[color=red]MedicineCabinet: Playing Caught Dialogue.[/color]")

	SceneDirector.clear_active_dialogue_balloons()

	if GameManager:
		if not DialogueManager.dialogue_ended.is_connected(GameManager.restore_world_after_object_dialogue):
			DialogueManager.dialogue_ended.connect(
				GameManager.restore_world_after_object_dialogue,
				CONNECT_ONE_SHOT
			)

	DialogueManager.show_dialogue_balloon_scene(
		"res://conversation/conversationballoon.tscn",
		caught_dialogue_resource,
		caught_dialogue_start_id
	)
