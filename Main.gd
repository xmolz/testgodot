# Main.gd (script attached to your 'Main' root node)
extends Control

# --- Level-Specific Event Resources ---
@export var aida_dialogue_resource: DialogueResource
@export var aida_explanation_data: ExplanationData

# --- Node References ---
@onready var level_state_manager: LevelStateManager = $LevelStateManager


func _ready():
	# We must wait for one frame. This is a crucial step.
	await get_tree().process_frame

	# --- 1. Hide UI Button on Start ---
	if is_instance_valid(GameManager.insurance_form_button_ui):
		GameManager.insurance_form_button_ui.hide()
	else:
		print_rich("[color=orange]Main.gd: Could not hide insurance button on start, GameManager reference is invalid.[/color]")

	# --- 2. Setup Global Signals ---
	if GameManager:
		# Connect to signal so we know when Aida finishes talking
		GameManager.character_conversation_ended.connect(_on_character_conversation_ended)

		# Register this level's state manager
		if is_instance_valid(level_state_manager):
			GameManager.register_level_state_manager(level_state_manager)
		else:
			print_rich("[color=red]%s: LevelStateManager node not found...[/color]" % name)
	else:
		print_rich("[color=red]%s: GameManager not found.[/color]" % name)


func _exit_tree():
	if GameManager and is_instance_valid(level_state_manager):
		if GameManager.current_level_state_manager == level_state_manager:
			GameManager.register_level_state_manager(null)
			print_rich("[color=yellow]%s: Unregistered its LevelStateManager.[/color]" % name)


# --- SIGNAL HANDLERS ---

func _on_character_conversation_ended(resource: DialogueResource):
	if resource == aida_dialogue_resource:
		var just_spoke_to_aida = level_state_manager.get_level_flag("has_spoken_to_aida")
		var explanation_shown = level_state_manager.get_level_flag("aida_explanation_shown")

		if just_spoke_to_aida and not explanation_shown:
			level_state_manager.set_level_flag("aida_explanation_shown", true)
			level_state_manager.set_level_flag("insurance_button_unlocked", true)

			# Add a slight delay to let the game world "breathe" before the pop-up
			await get_tree().create_timer(0.5).timeout

			GameManager.start_explanation(aida_explanation_data, self)
