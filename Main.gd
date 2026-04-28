# Main.gd (script attached to your 'Main' root node)
extends Control

# --- Level-Specific Event Resources ---
@export var aida_dialogue_resource: DialogueResource
@export var aida_explanation_data: ExplanationData

@export_group("UI Settings")
@export var enable_journal_notification: bool = true

# --- Node References ---
@onready var level_state_manager: LevelStateManager = $LevelStateManager
@onready var sergey_interactable: Interactable = $Sergei_Path/Sergei/InteractionArea
@onready var mcbucket_interactable: Interactable = $McBucket_Path/McBucket/InteractionArea
@onready var memory_box_interactable: Interactable = $MemoryBox


func _ready():
	_inject_progression_blockers()

	# We must wait for one frame. This is a crucial step.
	await get_tree().process_frame

	# --- Apply Journal Notification Setting ---
	if GameManager and is_instance_valid(GameManager.journal_button_ui):
		GameManager.journal_button_ui.set_notification_enabled(enable_journal_notification)

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

func _inject_progression_blockers():
	var generic_dialogue = preload("res://generic_lines.dialogue")

	var act_talk_no_aida = ShowCustomDialogueAction.new()
	act_talk_no_aida.dialogue_resource = generic_dialogue
	act_talk_no_aida.dialogue_checkpoint = "block_talk_no_aida"

	var resp_talk_no_aida = InteractionResponse.new()
	resp_talk_no_aida.verb_id = "talk_to"
	resp_talk_no_aida.required_flag_id = "has_spoken_to_aida"
	resp_talk_no_aida.required_flag_value = false
	resp_talk_no_aida.actions_to_perform.append(act_talk_no_aida)

	var act_talk_no_box = ShowCustomDialogueAction.new()
	act_talk_no_box.dialogue_resource = generic_dialogue
	act_talk_no_box.dialogue_checkpoint = "block_talk_no_memory_box"

	var resp_talk_no_box = InteractionResponse.new()
	resp_talk_no_box.verb_id = "talk_to"
	resp_talk_no_box.required_flag_id = "has_tried_memory_box"
	resp_talk_no_box.required_flag_value = false
	resp_talk_no_box.actions_to_perform.append(act_talk_no_box)

	var act_use_box_no_aida = ShowCustomDialogueAction.new()
	act_use_box_no_aida.dialogue_resource = generic_dialogue
	act_use_box_no_aida.dialogue_checkpoint = "block_memory_box_no_aida"

	var resp_use_box_no_aida = InteractionResponse.new()
	resp_use_box_no_aida.verb_id = "use"
	resp_use_box_no_aida.required_flag_id = "has_spoken_to_aida"
	resp_use_box_no_aida.required_flag_value = false
	resp_use_box_no_aida.actions_to_perform.append(act_use_box_no_aida)

	if is_instance_valid(sergey_interactable):
		sergey_interactable.interactions.insert(0, resp_talk_no_box)
		sergey_interactable.interactions.insert(0, resp_talk_no_aida)

	if is_instance_valid(mcbucket_interactable):
		mcbucket_interactable.interactions.insert(0, resp_talk_no_box)
		mcbucket_interactable.interactions.insert(0, resp_talk_no_aida)

	if is_instance_valid(memory_box_interactable):
		memory_box_interactable.interactions.insert(0, resp_use_box_no_aida)
