# Main.gd (script attached to your 'Main' root node)
extends Control

# --- Level-Specific Event Resources ---
# These variables hold the data for events that happen in this specific level.
@export var aida_dialogue_resource: DialogueResource
@export var aida_explanation_data: ExplanationData

# --- Node References ---
# We only need a reference to the nodes that this script directly interacts with.
@onready var level_state_manager: LevelStateManager = $LevelStateManager


func _ready():
	# We must wait for one frame. This is a crucial step.
	# It guarantees that the GameManager (Autoload) has finished its own _ready()
	# function and has found all the UI nodes, including the insurance button.
	await get_tree().process_frame

	# --- THIS IS THE FIX ---
	# Now that we know the GameManager is ready, we can safely access its variables.
	# We get the button reference FROM the GameManager and then hide it.
	if is_instance_valid(GameManager.insurance_form_button_ui):
		GameManager.insurance_form_button_ui.hide()
	else:
		print_rich("[color=orange]Main.gd: Could not hide insurance button on start, GameManager reference is invalid.[/color]")
	# --- END OF FIX ---

	# Connect to the GameManager's broadcast signal so we know when conversations end.
	if GameManager:
		GameManager.character_conversation_ended.connect(_on_character_conversation_ended)

	# --- Register this level's state manager with the GameManager ---
	if not is_instance_valid(level_state_manager):
		print_rich("[color=red]%s: LevelStateManager node not found...[/color]" % name)
		return

	if GameManager:
		GameManager.register_level_state_manager(level_state_manager)
	else:
		print_rich("[color=red]%s: GameManager not found.[/color]" % name)


func _exit_tree():
	# When the level is unloaded, unregister its LevelStateManager
	if GameManager and is_instance_valid(level_state_manager):
		if GameManager.current_level_state_manager == level_state_manager:
			GameManager.register_level_state_manager(null)
			print_rich("[color=yellow]%s: Unregistered its LevelStateManager.[/color]" % name)


# This function runs every time ANY character conversation ends.
func _on_character_conversation_ended(resource: DialogueResource):
	# We check if the conversation that just ended was AIda's.
	if resource == aida_dialogue_resource:
		var just_spoke_to_aida = level_state_manager.get_level_flag("has_spoken_to_aida")
		var explanation_shown = level_state_manager.get_level_flag("aida_explanation_shown")

		if just_spoke_to_aida and not explanation_shown:
			# Mark that the explanation has been shown so this doesn't run again.
			level_state_manager.set_level_flag("aida_explanation_shown", true)

			# Permanently unlock the button for the rest of the game.
			level_state_manager.set_level_flag("insurance_button_unlocked", true)

			# Tell the GameManager to start the explanation tutorial.
			GameManager.start_explanation(aida_explanation_data, self)
