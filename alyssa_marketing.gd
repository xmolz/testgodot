extends Control

func _ready():
	# Hide the mouse cursor to make the screenshot look clean
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Load the dialogue and show the balloon
	var dialogue_res = load("res://dialogue/alyssa_marketing.dialogue")
	DialogueManager.show_dialogue_balloon_scene("res://conversationballoon.tscn", dialogue_res, "start")
