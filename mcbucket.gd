extends CharacterBody2D

enum State { IDLE, HIGH, INVIGIROL, SLEEPING }

const MCBUCKET_ADVANCED_OVERLAY = "res://mcbucket_advanced_overlay.tscn"

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interactable_component = $InteractionArea
@onready var movement_controller: WaypointMovement = $MovementController

# --- Interaction State Variables ---
var _is_interacting_with_me: bool = false
var _resume_walk_timer: Timer
var _patience_timer: Timer 

func _ready():
	# 1. Setup Resume Timer (Wait after talking)
	_resume_walk_timer = Timer.new()
	_resume_walk_timer.one_shot = true
	_resume_walk_timer.wait_time = 5.0
	add_child(_resume_walk_timer)
	_resume_walk_timer.timeout.connect(_on_resume_timer_timeout)

	# 2. Setup Patience Timer (Wait for player to arrive)
	_patience_timer = Timer.new()
	_patience_timer.one_shot = true
	_patience_timer.wait_time = 8.0 
	add_child(_patience_timer)
	_patience_timer.timeout.connect(_on_patience_timeout)

	# 3. Connect signals
	if interactable_component:
		if not interactable_component.interaction_pending.is_connected(_on_interaction_pending):
			interactable_component.interaction_pending.connect(_on_interaction_pending)
		if not interactable_component.interaction_started.is_connected(_on_interaction_started):
			interactable_component.interaction_started.connect(_on_interaction_started)
		if not interactable_component.interaction_processed.is_connected(_on_interaction_finished):
			interactable_component.interaction_processed.connect(_on_interaction_finished)

	if GameManager:
		GameManager.interaction_complete.connect(_on_global_interaction_complete)

	# Programmatically add the "Give Toilet Paper" interaction
	if interactable_component:
		# 1. Response for when McBucket is SLEEPING
		var sleep_response = InteractionResponse.new()
		sleep_response.verb_id = "give"
		sleep_response.required_item_id = "hospital_toilet_paper"
		sleep_response.required_flag_id = "mcbucket_zanopram_used"
		sleep_response.required_flag_value = true

		var sleep_dialogue_action = ShowCustomDialogueAction.new()
		sleep_dialogue_action.dialogue_resource = load("res://mcbucket_give_tp.dialogue")
		sleep_dialogue_action.dialogue_checkpoint = "sleeping"
		sleep_response.actions_to_perform.append(sleep_dialogue_action)

		# 2. Response for when McBucket is AWAKE
		var give_tp_response = InteractionResponse.new()
		give_tp_response.verb_id = "give"
		give_tp_response.required_item_id = "hospital_toilet_paper"
		give_tp_response.required_flag_id = "mcbucket_zanopram_used"
		give_tp_response.required_flag_value = false

		var give_tp_action = ShowCustomDialogueAction.new()
		give_tp_action.dialogue_resource = load("res://mcbucket_give_tp.dialogue")
		give_tp_action.dialogue_checkpoint = "start"

		var remove_tp_action = RemoveItemAction.new()
		remove_tp_action.item_id_to_remove = "hospital_toilet_paper"

		# Append dialogue first, then remove item
		give_tp_response.actions_to_perform.append(give_tp_action)
		give_tp_response.actions_to_perform.append(remove_tp_action)

		# Add both to the interactable component
		interactable_component.interactions.append(sleep_response)
		interactable_component.interactions.append(give_tp_response)

	# 4. Check State
	await get_tree().process_frame
	if not GameManager: return

	if GameManager.get_current_level_flag("mcbucket_cannathink_used"):
		change_state(State.HIGH)
	elif GameManager.get_current_level_flag("mcbucket_invigirol_used"):
		change_state(State.INVIGIROL)
	elif GameManager.get_current_level_flag("mcbucket_zanopram_used"):
		change_state(State.SLEEPING)
	else:
		change_state(State.IDLE)

func change_state(new_state: State):
	if not animation_player or not interactable_component:
		push_warning("McBucket script is missing node references!")
		return

	if GameManager:
		GameManager.set_current_level_flag("mcbucket_cannathink_used", new_state == State.HIGH)
		GameManager.set_current_level_flag("mcbucket_invigirol_used", new_state == State.INVIGIROL)
		GameManager.set_current_level_flag("mcbucket_zanopram_used", new_state == State.SLEEPING)

	match new_state:
		State.IDLE:
			animation_player.play("idle")
			interactable_component.character_conversation_scene_path = MCBUCKET_ADVANCED_OVERLAY
		State.HIGH:
			animation_player.play("high")
			interactable_component.character_conversation_scene_path = MCBUCKET_ADVANCED_OVERLAY
		State.INVIGIROL:
			animation_player.play("invigirol", -1, 4.0)
			interactable_component.character_conversation_scene_path = MCBUCKET_ADVANCED_OVERLAY
		State.SLEEPING:
			animation_player.play("sleeping")
			interactable_component.character_conversation_scene_path = "" # Cannot talk to him


# --- SIGNAL HANDLERS ---

func _on_interaction_pending():
	_is_interacting_with_me = true 
	_resume_walk_timer.stop()
	_patience_timer.start()
	if movement_controller:
		movement_controller.pause_movement()

func _on_interaction_started():
	_patience_timer.stop()

func _on_patience_timeout():
	_is_interacting_with_me = false
	if movement_controller:
		movement_controller.resume_movement()

func _on_interaction_finished():
	if GameManager.current_interaction_state == GameManager.InteractionState.CONVERSATION:
		if not GameManager.character_conversation_ended.is_connected(_on_global_conversation_ended):
			GameManager.character_conversation_ended.connect(_on_global_conversation_ended, CONNECT_ONE_SHOT)
	else:
		_start_resume_countdown()

func _on_global_conversation_ended(_resource):
	_start_resume_countdown()

func _start_resume_countdown():
	visible = true
	modulate.a = 1.0
	_resume_walk_timer.start()

func _on_resume_timer_timeout():
	if GameManager.current_interaction_state == GameManager.InteractionState.CONVERSATION:
		return
	_is_interacting_with_me = false
	if movement_controller:
		movement_controller.resume_movement()

func _on_global_interaction_complete():
	if _is_interacting_with_me:
		_patience_timer.stop() 
		_is_interacting_with_me = false 
		_start_resume_countdown()
