# conversationeventmanager.gd
extends Node


# signal to request a background
# we pass the texture path as an argument.
signal change_conversation_background(new_background_texture_path: String)
signal tv_state_change_requested(is_off: bool)
signal mcbucket_tv_reaction_requested(is_tv_off: bool)
signal mcbucket_state_change_requested(new_state: int)

func request_tv_state(is_off: bool) -> void:
	tv_state_change_requested.emit(is_off)

func request_mcbucket_tv_reaction(is_tv_off: bool) -> void:
	mcbucket_tv_reaction_requested.emit(is_tv_off)

func request_mcbucket_state(new_state: int) -> void:
	mcbucket_state_change_requested.emit(new_state)

# you can add more conversation-related
# g., for character sprite changes, sound effects, etc.
var show_special_response: bool = false

# sergey's variable
var has_heard_fresh_start_line: bool = false
var asked_sergey_duration: bool = false
var asked_sergey_identity: bool = false

func reset_run_state():
	show_special_response = false
	has_heard_fresh_start_line = false
	asked_sergey_duration = false
	asked_sergey_identity = false
