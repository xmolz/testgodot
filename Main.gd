# Main.gd (script attached to your 'Main' root node)
extends Control

# --- EXISTING CODE ---
# Path to your LevelStateManager node within this level scene
@onready var level_state_manager: LevelStateManager = $LevelStateManager
# Ensure you have a node named "LevelStateManager" as a child of this level root,
# and that it has LevelStateManager.gd attached.

# --- NEW NODE REFERENCES ---
# Get references to your UI layers so we can hide/show them.
@onready var verb_ui: CanvasLayer = $VerbUI_CanvasLayer
@onready var inventory_ui: CanvasLayer = $InventoryUI_CanvasLayer


func _ready():
	# --- EXISTING CODE ---
	if not is_instance_valid(level_state_manager):
		print_rich("[color=red]%s: LevelStateManager node not found or invalid at path '$LevelStateManager'![/color]" % name)
		return

	if GameManager:
		GameManager.register_level_state_manager(level_state_manager)
	else:
		print_rich("[color=red]%s: GameManager not found. Cannot register LevelStateManager.[/color]" % name)


func _exit_tree():
	# --- EXISTING CODE ---
	# When the level is unloaded, unregister its LevelStateManager
	if GameManager and is_instance_valid(level_state_manager): # Check if LSM is still valid
		if GameManager.current_level_state_manager == level_state_manager:
			GameManager.register_level_state_manager(null)
			print_rich("[color=yellow]%s: Unregistered its LevelStateManager.[/color]" % name)


# --- NEW FUNCTIONS ---
# These functions will be called by the Boot script and GameManager
# to control the visibility of the entire game scene, including its UI layers.
