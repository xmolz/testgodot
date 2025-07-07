# YourLevelName.gd (e.g., attached to Level1 root node)
extends Node2D # Or Node, or whatever your level root is

# Path to your LevelStateManager node within this level scene
@onready var level_state_manager: LevelStateManager = $LevelStateManager
# Ensure you have a node named "LevelStateManager" as a child of this level root,
# and that it has LevelStateManager.gd attached.

func _ready():
	if not is_instance_valid(level_state_manager):
		print_rich("[color=red]%s: LevelStateManager node not found or invalid at path '$LevelStateManager'![/color]" % name)
		return

	if GameManager:
		GameManager.register_level_state_manager(level_state_manager)
	else:
		print_rich("[color=red]%s: GameManager not found. Cannot register LevelStateManager.[/color]" % name)

func _exit_tree():
	# When the level is unloaded, unregister its LevelStateManager
	if GameManager and is_instance_valid(level_state_manager): # Check if LSM is still valid
		if GameManager.current_level_state_manager == level_state_manager:
			GameManager.register_level_state_manager(null)
			print_rich("[color=yellow]%s: Unregistered its LevelStateManager.[/color]" % name)
