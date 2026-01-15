extends Node2D

# Define the states corresponding to your logic steps
enum ToiletState { NORMAL, HAS_PAPER, CLOGGED }

@onready var animation_player: AnimationPlayer = $AnimationPlayer
# This assumes your child node with Interactable.gd is named "InteractionArea"
@onready var interactable_component: Interactable = $InteractionArea 

func _ready():
	# Wait one frame to ensure GameManager and its dictionaries are ready
	await get_tree().process_frame
	if not GameManager: return
	
	_restore_state()

func _restore_state():
	# We check the flags in reverse order of severity.
	# If "clogged" is true, it overrides "has_paper".
	if GameManager.get_current_level_flag("toilet_clogged"):
		change_state(ToiletState.CLOGGED)
	elif GameManager.get_current_level_flag("toilet_has_paper"):
		change_state(ToiletState.HAS_PAPER)
	else:
		change_state(ToiletState.NORMAL)

# This function is called by CallMethodAction from the Interactable child.
# We accept an int because Action arguments in the Inspector are often passed as generic integers.
func change_state(new_state_int: int):
	var new_state = new_state_int as ToiletState
	
	# 1. Update the Level Flags via GameManager
	# We updates flags here so the logic is centralized in the object script.
	if GameManager:
		if new_state == ToiletState.HAS_PAPER:
			GameManager.set_current_level_flag("toilet_has_paper", true)
		elif new_state == ToiletState.CLOGGED:
			GameManager.set_current_level_flag("toilet_clogged", true)

	# 2. Handle Visuals and Behavior
	match new_state:
		ToiletState.NORMAL:
			if animation_player: 
				# Assuming you have a default state or just want it to stop
				if animation_player.has_animation("idle"):
					animation_player.play("idle")
				else:
					animation_player.stop()
			print_rich("[color=cyan]Toilet State: NORMAL[/color]")
			
		ToiletState.HAS_PAPER:
			# Logic: Paper is in, but not flushed yet.
			# Visuals: Usually no visual change yet, as the paper is inside the bowl/pipe.
			print_rich("[color=cyan]Toilet State: HAS_PAPER (Pending Flush)[/color]")
			
		ToiletState.CLOGGED:
			# Logic: It was flushed with paper.
			# Visuals: Play the error animation (blinking lights).
			if animation_player: 
				if animation_player.has_animation("error"):
					animation_player.play("error")
				else:
					push_warning("HospitalToilet: 'error' animation not found in AnimationPlayer.")
			print_rich("[color=red]Toilet State: CLOGGED[/color]")
