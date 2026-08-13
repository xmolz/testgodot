@tool
class_name RoomLightSpill
extends Node2D

## Doorway light-spill glow. Origin sits ON the room edge; the glow extends
## inward. Additive blend: invisible on pure-white backgrounds by design.

@export var spill_length: float = 450.0:
	set(value):
		spill_length = max(value, 1.0)
		_apply()

@export var spill_height: float = 900.0:
	set(value):
		spill_height = max(value, 1.0)
		_apply()

@export var from_left: bool = true:
	set(value):
		from_left = value
		_apply()

@export var light_color: Color = Color(1.0, 0.98, 0.92, 1.0):
	set(value):
		light_color = value
		_apply()

@export_range(0.0, 1.0) var peak_alpha: float = 0.8:
	set(value):
		peak_alpha = value
		_apply()

@export_range(0.2, 6.0) var falloff: float = 2.2:
	set(value):
		falloff = value
		_apply()

@export_range(0.0, 1.0) var vertical_softness: float = 0.35:
	set(value):
		vertical_softness = value
		_apply()

@onready var _spill: Sprite2D = $Spill

func _ready() -> void:
	_apply()

func _apply() -> void:
	if _spill == null:
		return
	var tex_size: Vector2 = _spill.texture.get_size()
	_spill.scale = Vector2(spill_length / tex_size.x, spill_height / tex_size.y)
	_spill.position = Vector2(0.0 if from_left else -spill_length, -spill_height / 2.0)
	var mat := _spill.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("light_color", light_color)
		mat.set_shader_parameter("peak_alpha", peak_alpha)
		mat.set_shader_parameter("falloff", falloff)
		mat.set_shader_parameter("from_left", from_left)
		mat.set_shader_parameter("vertical_softness", vertical_softness)
