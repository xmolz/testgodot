extends CharacterBody2D

enum State { IDLE, HIGH, INVIGIROL, SLEEPING }

const THINKING_DIALOGUE_SCENE = preload("res://mcbucket_thinking_conversation.tscn")
const INVIGIROL_DIALOGUE_SCENE = preload("res://mcbucket_invigirol_conversation.tscn")
const DEFAULT_DIALOGUE_SCENE = preload("res://mcbucket_default_conversation.tscn")

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
			interactable_component.character_conversation_overlay_scene = DEFAULT_DIALOGUE_SCENE
		State.HIGH:
			animation_player.play("high")
			interactable_component.character_conversation_overlay_scene = THINKING_DIALOGUE_SCENE
			print_rich("[color=cyan]McBucket state changed to HIGH.[/color]")
		State.INVIGIROL:
			animation_player.play("invigirol", -1, 4.0)
			interactable_component.character_conversation_overlay_scene = INVIGIROL_DIALOGUE_SCENE 
			print_rich("[color=cyan]McBucket state changed to INVIGIROL.[/color]")
		State.SLEEPING:
			animation_player.play("sleeping")
			interactable_component.character_conversation_overlay_scene = null
			print_rich("[color=cyan]McBucket state changed to SLEEPING.[/color]")


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
