extends CharacterBody2D

const ROOM_THRESHOLD_Y: float = 1000.0 
var _was_in_main_room: bool = true 
var _is_interacting_with_me: bool = false

# --- References ---
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interactable_component: Interactable = $InteractionArea
@onready var movement_controller: WaypointMovement = $MovementController

# --- Timers ---
var _resume_walk_timer: Timer
var _patience_timer: Timer # NEW: Safety timer if player never arrives

func _process(_delta):
	# (Logic unchanged)
	var is_currently_in_main = global_position.y < ROOM_THRESHOLD_Y
	if is_currently_in_main != _was_in_main_room:
		_was_in_main_room = is_currently_in_main
		if GameManager:
			GameManager.set_current_level_flag("aida_in_main_room", is_currently_in_main)

func _ready():
	# 1. Setup Resume Timer (Wait after talking)
	_resume_walk_timer = Timer.new()
	_resume_walk_timer.one_shot = true
	_resume_walk_timer.wait_time = 5.0
	add_child(_resume_walk_timer)
	_resume_walk_timer.timeout.connect(_on_resume_timer_timeout)

	# 2. NEW: Setup Patience Timer (Wait for player to arrive)
	_patience_timer = Timer.new()
	_patience_timer.one_shot = true
	_patience_timer.wait_time = 8.0 # Give player 8 seconds to walk to her
	add_child(_patience_timer)
	_patience_timer.timeout.connect(_on_patience_timeout)

	# 3. Connect signals
	if interactable_component:
		if not interactable_component.interaction_pending.is_connected(_on_interaction_pending):
			interactable_component.interaction_pending.connect(_on_interaction_pending)
		
		# NEW: Listen for actual start of interaction
		if not interactable_component.interaction_started.is_connected(_on_interaction_started):
			interactable_component.interaction_started.connect(_on_interaction_started)
			
		if not interactable_component.interaction_processed.is_connected(_on_interaction_finished):
			interactable_component.interaction_processed.connect(_on_interaction_finished)

	if GameManager:
		GameManager.interaction_complete.connect(_on_global_interaction_complete)
	
	if animation_player:
		animation_player.play("idle")

# --- SIGNAL HANDLERS ---

func _on_interaction_pending():
	print("Aida: Player clicked me. Pausing and waiting for arrival...")
	_is_interacting_with_me = true 
	
	# Stop Resume timer (we are busy now)
	_resume_walk_timer.stop()
	
	# Start Patience timer (If player doesn't arrive in 8s, we resume)
	_patience_timer.start()
	
	if movement_controller:
		movement_controller.pause_movement()
	
	if animation_player:
		animation_player.play("idle")

func _on_interaction_started():
	print("Aida: Player arrived! Interaction started. Stopping Patience timer.")
	# Player made it! We don't need to auto-resume anymore, the dialogue will handle it.
	_patience_timer.stop()

func _on_patience_timeout():
	# If this fires, the player clicked but never showed up.
	print("[color=orange]Aida: Player took too long to arrive. Resuming patrol.[/color]")
	_is_interacting_with_me = false
	if movement_controller:
		movement_controller.resume_movement()

func _on_interaction_finished():
	if GameManager.current_interaction_state == GameManager.InteractionState.CONVERSATION:
		print("Aida: Interaction processed, but in Conversation Overlay. Holding...")
		if not GameManager.character_conversation_ended.is_connected(_on_global_conversation_ended):
			GameManager.character_conversation_ended.connect(_on_global_conversation_ended, CONNECT_ONE_SHOT)
	else:
		_start_resume_countdown()

func _on_global_conversation_ended(_resource):
	_start_resume_countdown()

func _start_resume_countdown():
	visible = true
	modulate.a = 1.0
	print("Aida: Interaction done. Waiting 5 seconds before walking...")
	_resume_walk_timer.start()

func _on_resume_timer_timeout():
	if GameManager.current_interaction_state == GameManager.InteractionState.CONVERSATION:
		return
		
	print("Aida: 5 seconds passed. Resuming patrol.")
	_is_interacting_with_me = false
	if movement_controller:
		movement_controller.resume_movement()

func _on_global_interaction_complete():
	if _is_interacting_with_me:
		# Ensure patience timer is killed if we finished successfully
		_patience_timer.stop() 
		print("Aida: Global interaction complete. Starting resume countdown.")
		_is_interacting_with_me = false 
		_start_resume_countdown()
