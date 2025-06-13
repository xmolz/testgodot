extends Area2D

var player_in_zone := false

func _ready():
	set_process(true)  # Enables the _process() function

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_zone = true
		print("Player has entered NPC interaction zone!")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_zone = false
		print("Player has left NPC interaction zone.")

func _process(delta):
	if player_in_zone and Input.is_action_just_pressed("talk_to_npc"):
		var dlg = load("res://testdialogue.dialogue")
		DialogueManager.show_dialogue_balloon(dlg, "start")
