extends Node2D

enum State { IDLE, HIGH, INVIGIROL, SLEEPING }

# --- Step 1: Define a constant for the new dialogue scene ---
# Make sure the path "res://mcbucket_invigirol_conversation.tscn" is correct for your project.
const THINKING_DIALOGUE_SCENE = preload("res://mcbucket_thinking_conversation.tscn")
const INVIGIROL_DIALOGUE_SCENE = preload("res://mcbucket_invigirol_conversation.tscn") # ADD THIS LINE
const DEFAULT_DIALOGUE_SCENE = preload("res://mcbucket_default_conversation.tscn")


@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interactable_component: Interactable = $InteractionArea


func _ready():
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

	# --- (No changes needed in this logic block) ---
	if GameManager:
		GameManager.set_current_level_flag("mcbucket_cannathink_used", new_state == State.HIGH)
		GameManager.set_current_level_flag("mcbucket_invigirol_used", new_state == State.INVIGIROL)
		GameManager.set_current_level_flag("mcbucket_zanopram_used", new_state == State.SLEEPING)
	# ---

	match new_state:
		State.IDLE:
			animation_player.play("idle")
			# (RECOMMENDED ADDITION) Reset to default dialogue behavior
			interactable_component.character_conversation_overlay_scene = DEFAULT_DIALOGUE_SCENE
		State.HIGH:
			animation_player.play("high")
			interactable_component.character_conversation_overlay_scene = THINKING_DIALOGUE_SCENE
			print_rich("[color=cyan]McBucket state changed to HIGH.[/color]")
		State.INVIGIROL:
			animation_player.play("invigirol", -1, 4.0)
			# --- Step 2: Assign the conversation scene when the state changes ---
			interactable_component.character_conversation_overlay_scene = INVIGIROL_DIALOGUE_SCENE # ADD THIS LINE
			print_rich("[color=cyan]McBucket state changed to INVIGIROL.[/color]")
		State.SLEEPING:
			animation_player.play("sleeping")
			# (Optional) You could also clear the conversation here if a sleeping character can't talk
			interactable_component.character_conversation_overlay_scene = null
			print_rich("[color=cyan]McBucket state changed to SLEEPING.[/color]")
