# LogoSplash.gd
extends Control

# Define a signal that this scene will emit when it's done.
signal splash_finished

# Get a reference to the AnimationPlayer that animates your logo.
# I'm assuming it's named "LogoAnimator" based on your screenshot.
@onready var logo_animator: AnimationPlayer = $LogoLabel/LogoAnimator

func _ready():
	# Connect to the AnimationPlayer's "animation_finished" signal.
	# When the animation is done, we'll call our own function.
	logo_animator.animation_finished.connect(_on_animation_finished)

	# Start playing the logo animation (assuming it's named "play_logo")
	logo_animator.play("play_logo")

func _on_animation_finished(_anim_name: String):
	# The animation is done. Now we emit our custom signal.
	splash_finished.emit()

	# And finally, remove the splash screen from the game.
	queue_free()
