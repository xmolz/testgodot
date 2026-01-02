extends CharacterBody2D

# 1. Get a reference to the AnimationPlayer node
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# 2. Get a reference to the InteractionArea (useful for later if he needs dialogue)
@onready var interactable_component = $InteractionArea

func _ready():
	# 3. Play the 'idle' animation as soon as the node enters the scene
	# Make sure the animation name in your AnimationPlayer tab is exactly "idle" (case-sensitive)
	animation_player.play("idle")
