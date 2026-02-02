extends Node2D

enum ToiletState { NORMAL, HAS_PAPER, CLOGGED }

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interactable_component: Interactable = $InteractionArea 

func _ready():
	await get_tree().process_frame
	if not GameManager: return
	_restore_state()

func _restore_state():
	if GameManager.get_current_level_flag("toilet_clogged"):
		change_state(ToiletState.CLOGGED)
	elif GameManager.get_current_level_flag("toilet_has_paper"):
		change_state(ToiletState.HAS_PAPER)
	else:
		change_state(ToiletState.NORMAL)

func change_state(new_state_int: int):
	var new_state = new_state_int as ToiletState
	
	if GameManager:
		# --- UPDATED LOGIC: Explicitly handle ALL flags ---
		match new_state:
			ToiletState.NORMAL:
				# Clear ALL flags when normal
				GameManager.set_current_level_flag("toilet_has_paper", false)
				GameManager.set_current_level_flag("toilet_clogged", false)
			ToiletState.HAS_PAPER:
				GameManager.set_current_level_flag("toilet_has_paper", true)
				# Ensure clogged is false
				GameManager.set_current_level_flag("toilet_clogged", false)
			ToiletState.CLOGGED:
				GameManager.set_current_level_flag("toilet_clogged", true)
				# (Optional: keep has_paper true if you want, or clear it. Usually clogged implies paper is stuck)
				# GameManager.set_current_level_flag("toilet_has_paper", true) 

	match new_state:
		ToiletState.NORMAL:
			if animation_player: 
				if animation_player.has_animation("idle"):
					animation_player.play("idle")
				else:
					animation_player.stop()
			print_rich("[color=cyan]Toilet State: NORMAL[/color]")
			
		ToiletState.HAS_PAPER:
			print_rich("[color=cyan]Toilet State: HAS_PAPER (Pending Flush)[/color]")
			
		ToiletState.CLOGGED:
			if animation_player: 
				if animation_player.has_animation("error"):
					animation_player.play("error")
				else:
					push_warning("HospitalToilet: 'error' animation not found.")
			print_rich("[color=red]Toilet State: CLOGGED[/color]")
