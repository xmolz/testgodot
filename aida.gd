extends CharacterBody2D

# 1. Get a reference to the AnimationPlayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 2. Get a reference to the InteractionArea (good practice to keep for when you add dialogue later)
@onready var interactable_component = $InteractionArea

func _ready():
	# 3. Play the 'idle' animation immediately
	animation_player.play("idle")
