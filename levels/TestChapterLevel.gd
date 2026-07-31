# testchapterlevel.gd — minimal generic level root for chapter launch test.
extends Control

@onready var level_state_manager: LevelStateManager = $LevelStateManager

func _ready():
	if GameManager:
		if is_instance_valid(level_state_manager):
			Flags.register_level_state_manager(level_state_manager)
	await get_tree().process_frame

func _exit_tree():
	if GameManager and is_instance_valid(level_state_manager):
		if Flags.current_level_state_manager == level_state_manager:
			Flags.register_level_state_manager(null)
			print_rich("[color=yellow]%s: Unregistered its LevelStateManager.[/color]" % name)
