extends Sprite2D

# We need a reference to the shader material to change its parameters.
@onready var tv_material: ShaderMaterial = material

func _ready():
	# Ensure the TV starts in the "On" state.
	# We will use another shader (like the aurora one) for the "On" state.
	# For now, this just sets the shutdown progress to 0.
	tv_material.set_shader_parameter("progress", 0.0)

# This is a simple test to trigger the effect by pressing Spacebar.
# You can call the turn_off() function from anywhere in your game!
func _input(event):
	if event.is_action_pressed("ui_accept"): # "ui_accept" is the Spacebar by default
		turn_off()

func turn_off():
	# A Tween is the perfect tool to animate a value over time.
	var tween = create_tween()

	# Tell the tween to animate the "progress" parameter inside our shader material.
	# It will go from its current value to 1.0 in 0.6 seconds.
	# The easing makes the animation start fast and end slow, which looks natural.
	tween.tween_property(tv_material, "shader_parameter/progress", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
