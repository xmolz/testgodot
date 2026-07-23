extends Sprite2D

# we need a reference to
@onready var tv_material: ShaderMaterial = material

func _ready():
	# ensure the tv starts in the "on" state.
	# we will use another shader
	# for now, this just sets the shutdown progress to 0.
	tv_material.set_shader_parameter("progress", 0.0)
	ConversationEventManager.tv_state_change_requested.connect(set_tv_state)


func set_tv_state(is_off: bool):
	var tween = create_tween()
	var target_val = 1.0 if is_off else 0.0
	tween.tween_property(tv_material, "shader_parameter/progress", target_val, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
