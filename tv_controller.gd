extends Sprite2D

# We need a reference to the shader material to change its parameters.
@onready var tv_material: ShaderMaterial = material

func _ready():
	# Ensure the TV starts in the "On" state.
	# We will use another shader (like the aurora one) for the "On" state.
	# For now, this just sets the shutdown progress to 0.
	tv_material.set_shader_parameter("progress", 0.0)


func set_tv_state(is_off: bool):
	var tween = create_tween()
	var target_val = 1.0 if is_off else 0.0
	tween.tween_property(tv_material, "shader_parameter/progress", target_val, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
