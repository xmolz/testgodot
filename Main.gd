# Main.gd (script attached to your 'Main' root node)
extends Control

# --- Level-Specific Event Resources ---
@export var aida_dialogue_resource: DialogueResource
@export var aida_explanation_data: ExplanationData

# --- UPDATED: Sergei References (Instead of McBucket) ---
# The new conversation scene for Sergei (e.g., Test_Conversation.tscn)
@export var sergei_after_drug_overlay_scene: PackedScene 
# The InteractionArea node attached to Sergei
@export var sergei_interactable: Interactable 

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

	# --- 3. Setup Logic for Level Flags (Sergei Reacting to Drugs) ---
	if is_instance_valid(level_state_manager):
		# A. Connect to the flag change signal (Real-time updates)
		if not level_state_manager.level_flag_changed.is_connected(_on_level_flag_changed):
			level_state_manager.level_flag_changed.connect(_on_level_flag_changed)

		# B. Check current state immediately (For Save/Load or Restart)
		# If McBucket is already asleep, switch Sergei's dialogue immediately.
		if level_state_manager.get_level_flag("mcbucket_zanopram_used"):
			_update_sergei_overlay()


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
			GameManager.start_explanation(aida_explanation_data, self)


func _on_level_flag_changed(flag_name: String, new_value: bool):
	# Listen specifically for the drug flag
	if flag_name == "mcbucket_zanopram_used" and new_value == true:
		print("Main.gd: McBucket drugged. Updating Sergei's dialogue.")
		_update_sergei_overlay()


# --- HELPER FUNCTIONS ---

func _update_sergei_overlay():
	# Check if we have the reference to Sergei and the new Scene
	if is_instance_valid(sergei_interactable) and sergei_after_drug_overlay_scene:
		# Overwrite Sergei's overlay scene with the new one
		sergei_interactable.character_conversation_overlay_scene = sergei_after_drug_overlay_scene
		print("Main.gd: Sergei's overlay successfully swapped.")
	else:
		print_rich("[color=red]Main.gd Error: Cannot swap Sergei's overlay. Check Inspector assignments.[/color]")
