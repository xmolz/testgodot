extends Node2D

# Make sure this path is correct.
const THINKING_DIALOGUE_SCENE = preload("res://mcbucket_thinking_conversation.tscn")

# --- CORRECTED NODE PATHS ---
# Get the AnimationPlayer by looking inside the InteractionArea child.
@onready var animation_player: AnimationPlayer = $InteractionArea/AnimationPlayer

# Get the Interactable component from the child named InteractionArea.
@onready var interactable_component: Interactable = $InteractionArea


# This runs when the level loads to restore McBucket's state if the item was already used.
func _ready():
	await get_tree().process_frame

	# First, check our "memory" flag
	if GameManager and GameManager.get_current_level_flag("mcbucket_cannathink_used"):
		print_rich("[color=cyan]McBucket (_ready): Flag is true. Restoring 'thinking' state.[/color]")

		# Now that 'animation_player' has the correct path, this will work.
		if animation_player:
			animation_player.play("idle_high")

		# And 'interactable_component' also has the correct path.
		if interactable_component:
			interactable_component.character_conversation_overlay_scene = THINKING_DIALOGUE_SCENE


# This is called by the CallMethodAction in the Inspector for the immediate change.
func on_player_used_cannathink():
	print_rich("[color=yellow]McBucket: I'm feeling... philosophical.[/color]")

	# This 'if' check will now succeed.
	if animation_player:
		animation_player.play("idle_high")

	# This 'if' check will also succeed, and the scene will be changed.
	if interactable_component:
		interactable_component.character_conversation_overlay_scene = THINKING_DIALOGUE_SCENE
		print_rich("[color=green]McBucket SUCCESS: Changed conversation scene to 'thinking' version.[/color]")
