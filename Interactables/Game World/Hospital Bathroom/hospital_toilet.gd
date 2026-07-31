extends Node2D

enum ToiletState { NORMAL, HAS_PAPER, CLOGGED }

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var interactable_component: Interactable = $InteractionArea 

func _ready():
	if is_instance_valid(Flags.current_level_state_manager):
		if not Flags.current_level_state_manager.level_state_restored.is_connected(apply_level_state):
			Flags.current_level_state_manager.level_state_restored.connect(apply_level_state)
		if Flags.current_level_state_manager.has_restored:
			apply_level_state()
	else:
		apply_level_state()

func apply_level_state() -> void:
	if Flags.get_level_flag("toilet_clogged"):
		change_state(ToiletState.CLOGGED, false)
	elif Flags.get_level_flag("toilet_has_paper"):
		change_state(ToiletState.HAS_PAPER, false)
	else:
		change_state(ToiletState.NORMAL, false)

func change_state(new_state_int: int, write_flags: bool = true):
	var new_state = new_state_int as ToiletState
	
	if GameManager and write_flags:
		# ***************** updated logic: explicitly handle all flags
		match new_state:
			ToiletState.NORMAL:
				# clear all flags when normal
				Flags.set_level_flag("toilet_has_paper", false)
				Flags.set_level_flag("toilet_clogged", false)
			ToiletState.HAS_PAPER:
				Flags.set_level_flag("toilet_has_paper", true)
				# ensure clogged is false
				Flags.set_level_flag("toilet_clogged", false)
			ToiletState.CLOGGED:
				Flags.set_level_flag("toilet_clogged", true)
				# (optional: keep has_paper true if
				# flags.set_level_flag("toilet_has_paper", true)

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
