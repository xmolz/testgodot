extends ObjectZoomOverlay

@export var caught_dialogue_resource: DialogueResource
@export var caught_dialogue_start_id: String = "aida_caught_snooping"

func _ready():
	super._ready()
	
	print_rich("[color=orange]MedicineCabinet: Zoom opened. Forcing Game Unpause to allow Aida to move.[/color]")
	get_tree().paused = false
	
	if GameManager and GameManager.current_level_state_manager:
		if not GameManager.current_level_state_manager.level_flag_changed.is_connected(_on_level_flag_changed):
			GameManager.current_level_state_manager.level_flag_changed.connect(_on_level_flag_changed)

func _on_level_flag_changed(flag_name: String, new_value: bool):
	if flag_name == "aida_in_main_room" and new_value == true:
		print_rich("[color=red]MedicineCabinet: AIDA RETURNED! Triggering caught sequence.[/color]")
		_trigger_forced_exit()

func _trigger_forced_exit():
	# Trigger the dialogue FIRST, before we delete this node
	if caught_dialogue_resource:
		_start_caught_dialogue()

	_cleanup_and_queue_free()

func _cleanup_and_queue_free():
	# Safely disconnect the signal to prevent crashes when Aida moves around later
	if GameManager and GameManager.current_level_state_manager:
		if GameManager.current_level_state_manager.level_flag_changed.is_connected(_on_level_flag_changed):
			GameManager.current_level_state_manager.level_flag_changed.disconnect(_on_level_flag_changed)

	# Inform the GameManager that we are returning to the main level.
	if GameManager:
		GameManager.persisting_verb_id = ""
		GameManager.cancel_current_action(false)
		if GameManager.has_method("exit_to_world_state"):
			GameManager.exit_to_world_state()

	# Emit our own signal before we disappear.
	zoom_view_closed.emit()

	# Remove the overlay from the game.
	queue_free()

func _start_caught_dialogue():
	print_rich("[color=red]MedicineCabinet: Playing Caught Dialogue.[/color]")

	# --- THE FIX: Connect the cleanup signal! ---
	# We tell DialogueManager: "When this text finishes, tell GameManager to unlock the player."
	if GameManager:
		DialogueManager.dialogue_ended.connect(
			GameManager._on_dialogue_ended_for_object_dialogue,
			CONNECT_ONE_SHOT
		)
	# --------------------------------------------

	DialogueManager.show_dialogue_balloon_scene(
		"res://conversationballoon.tscn",
		caught_dialogue_resource,
		caught_dialogue_start_id
	)
