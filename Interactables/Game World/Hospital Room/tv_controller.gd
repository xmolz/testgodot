extends Sprite2D

# we need a reference to
@onready var tv_material: ShaderMaterial = material

func _ready():
	if is_instance_valid(Flags.current_level_state_manager):
		if not Flags.current_level_state_manager.level_state_restored.is_connected(apply_level_state):
			Flags.current_level_state_manager.level_state_restored.connect(apply_level_state)
		if Flags.current_level_state_manager.has_restored:
			apply_level_state()
	
	ConversationEventManager.tv_state_change_requested.connect(set_tv_state)

func apply_level_state() -> void:
	var is_off = Flags.get_level_flag("tv_turned_off")
	var target_val = 1.0 if is_off else 0.0
	tv_material.set_shader_parameter("progress", target_val)

func set_tv_state(is_off: bool):
	var tween = create_tween()
	var target_val = 1.0 if is_off else 0.0
	tween.tween_property(tv_material, "shader_parameter/progress", target_val, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
