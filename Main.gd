# main.gd (script attached to your 'main' root node)
extends Control

# ----------(level-specific event resources)
@export var aida_dialogue_resource: DialogueResource
@export var aida_explanation_data: ExplanationData

@export_group("UI Settings")
@export var enable_journal_notification: bool = true
@export var force_assisted_mode: bool = false

# /////////////(node references)
@onready var level_state_manager: LevelStateManager = $LevelStateManager
@onready var sergey_interactable: Interactable = $Sergei_Path/Sergei/InteractionArea
@onready var mcbucket_interactable: Interactable = $McBucket_Path/McBucket/InteractionArea
@onready var memory_box_interactable: Interactable = $MemoryBox
@onready var level_hint_manager: LevelHintManager = $LevelHintManager


func _ready():
	_inject_progression_blockers()

	if GameManager:
		if is_instance_valid(level_state_manager):
			Flags.register_level_state_manager(level_state_manager)

	# we must wait for one frame. this is a crucial step.
	await get_tree().process_frame

	# ********************** debug: force assisted mode
	if GameManager and force_assisted_mode:
		Settings.assisted_mode = true
		Verbs.unlock_verb("think")
		GameManager.current_unread_hint = ""
		GameManager.last_read_hint = ""
	#

	# ----------------(apply journal notification setting)
	var journal_button = get_node_or_null("%JournalButtonUI")
	if is_instance_valid(journal_button):
		journal_button.set_notification_enabled(enable_journal_notification)

	# ////////////// 2. setup global signals
	if GameManager:
		# connect to signal so we know when aida finishes talking
		GameManager.character_conversation_ended.connect(_on_character_conversation_ended)

		if is_instance_valid(level_hint_manager):
			GameManager.current_hint_manager = level_hint_manager
		elif not is_instance_valid(level_state_manager):
			print_rich("[color=red]%s: LevelStateManager node not found...[/color]" % name)
	else:
		print_rich("[color=red]%s: GameManager not found.[/color]" % name)


func _exit_tree():
	if GameManager and is_instance_valid(level_state_manager):
		if Flags.current_level_state_manager == level_state_manager:
			Flags.register_level_state_manager(null)
			GameManager.current_hint_manager = null
			print_rich("[color=yellow]%s: Unregistered its LevelStateManager.[/color]" % name)


# ////////////////// signal handlers

func _on_character_conversation_ended(resource: DialogueResource):
	if resource == aida_dialogue_resource:
		var just_spoke_to_aida = level_state_manager.get_level_flag("has_spoken_to_aida")
		var explanation_shown = level_state_manager.get_level_flag("aida_explanation_shown")

		if just_spoke_to_aida and not explanation_shown:
			level_state_manager.set_level_flag("aida_explanation_shown", true)
			level_state_manager.set_level_flag("insurance_button_unlocked", true)

			# add a slight delay to
			await get_tree().create_timer(0.5).timeout

			GameManager.start_explanation(aida_explanation_data, self)

func _inject_progression_blockers():
	var generic_dialogue = preload("res://dialogue/generic_lines.dialogue")

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
