extends CharacterBody2D


# Add these variables at the top of Aida.gd
const ROOM_THRESHOLD_Y: float = 1000.0 # ADJUST THIS NUMBER to the Y coordinate of the floor between rooms
var _was_in_main_room: bool = true # To track state changes


# --- References ---
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interactable_component: Interactable = $InteractionArea
@onready var movement_controller: WaypointMovement = $MovementController

# --- Timers ---
var _resume_walk_timer: Timer

func _process(_delta):
	# Determine where she is currently based on Y height
	# Assuming Top Room (Main) is < 1000 and Bottom (Bathroom) is > 1000
	var is_currently_in_main = global_position.y < ROOM_THRESHOLD_Y
	
	# Only update the Game Manager if the state has CHANGED
	if is_currently_in_main != _was_in_main_room:
		_was_in_main_room = is_currently_in_main
		
		# Update the flag
		if GameManager:
			print("Aida: Crossed threshold. Entering %s." % ["Main Room" if is_currently_in_main else "Bathroom"])
			GameManager.set_current_level_flag("aida_in_main_room", is_currently_in_main)

func _ready():
	# 1. Setup the Resume Timer (Wait 5 seconds after talking)
	_resume_walk_timer = Timer.new()
	_resume_walk_timer.one_shot = true
	_resume_walk_timer.wait_time = 5.0
	add_child(_resume_walk_timer)
	_resume_walk_timer.timeout.connect(_on_resume_timer_timeout)

	# 2. Connect to the InteractionArea signals
	if interactable_component:
		# Triggered when player CLICKS (before reaching her)
		if not interactable_component.interaction_pending.is_connected(_on_interaction_pending):
			interactable_component.interaction_pending.connect(_on_interaction_pending)
		
		# Triggered when the action script (Talk To) says it's done spawning the dialogue
		if not interactable_component.interaction_processed.is_connected(_on_interaction_finished):
			interactable_component.interaction_processed.connect(_on_interaction_finished)

	# 3. Start default state
	if animation_player:
		animation_player.play("idle")

# --- SIGNAL HANDLERS ---

func _on_interaction_pending():
	print("Aida: Player clicked me. Stopping movement immediately.")
	
	# Stop the resume timer if it was already counting down
	_resume_walk_timer.stop()
	
	# Pause movement logic
	if movement_controller:
		movement_controller.pause_movement()
	
	# Force idle animation
	if animation_player:
		animation_player.play("idle")

func _on_interaction_finished():
	# This function runs when the "Action" is technically done.
	# HOWEVER, if the action was "Open Overlay", this fires immediately, not when the overlay closes.
	
	# Check GameManager State: Are we in a full-screen conversation?
	if GameManager.current_interaction_state == GameManager.InteractionState.CONVERSATION:
		print("Aida: Interaction processed, but Player is in a Conversation Overlay. Holding position...")
		
		# Wait for the global signal that the conversation ended
		if not GameManager.character_conversation_ended.is_connected(_on_global_conversation_ended):
			GameManager.character_conversation_ended.connect(_on_global_conversation_ended, CONNECT_ONE_SHOT)
	else:
		# Not a generic conversation (maybe just a text bubble), start timer immediately
		_start_resume_countdown()

func _on_global_conversation_ended(_resource):
	print("Aida: Overlay closed. Now starting 5s cooldown.")
	_start_resume_countdown()

func _start_resume_countdown():
	# Ensure she is visible (safety check)
	visible = true
	modulate.a = 1.0
	
	print("Aida: Waiting 5 seconds...")
	_resume_walk_timer.start()

func _on_resume_timer_timeout():
	# Safety check: Don't resume if the player started talking to us AGAIN during the 5 seconds
	if GameManager.current_interaction_state == GameManager.InteractionState.CONVERSATION:
		print("Aida: Timer finished, but Player is talking again! aborting resume.")
		return
		
	print("Aida: 5 seconds passed. Resuming patrol.")
	if movement_controller:
		movement_controller.resume_movement()
