# logosplash.gd
extends Control

# define a signal that this
signal splash_finished

# //////////////(get a reference to the animationplayer that animates your logo.)
# i'm assuming it's named "logoanimator"
@onready var logo_animator: AnimationPlayer = $LogoLabel/LogoAnimator

func _ready():
	# //////////////////////[connect to the animationplayer's "animation_finished" signal.]
	# when the animation is done,
	logo_animator.animation_finished.connect(_on_animation_finished)

	# start playing the logo animation
	logo_animator.play("splash_animation")

func _on_animation_finished(_anim_name: String):
	# the animation is done. now we emit our custom signal.
	splash_finished.emit()

	# and finally, remove the splash screen from the game.
	queue_free()
