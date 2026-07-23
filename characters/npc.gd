extends Area2D

var player_in_zone := false

func _ready():
	set_process(true)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_zone = true
		print("Player has entered NPC interaction zone!")

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_zone = false
		print("Player has left NPC interaction zone.")
