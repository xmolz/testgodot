extends "res://interactions/interactable.gd"

@onready var _button_sprite: Sprite2D = get_node_or_null("ButtonSprite")
var _button_outline_material: Material = null


func _ready() -> void:
	super._ready()
	if _button_sprite and _button_sprite.material:
		_button_outline_material = _button_sprite.material
		_button_sprite.material = null


func _on_mouse_entered() -> void:
	super._on_mouse_entered()
	if not OS.has_feature("mobile"):
		if _button_sprite and _button_outline_material:
			_button_sprite.material = _button_outline_material
			_button_sprite.material.set_shader_parameter("enable_outline", true)


func _on_mouse_exited() -> void:
	super._on_mouse_exited()
	if not OS.has_feature("mobile"):
		if _button_sprite:
			_button_sprite.material = null


func force_highlight(active: bool) -> void:
	super.force_highlight(active)
	if active:
		if _button_sprite and _button_outline_material:
			_button_sprite.material = _button_outline_material
			_button_sprite.material.set_shader_parameter("enable_outline", true)
	else:
		if not _is_mouse_over or OS.has_feature("mobile"):
			if _button_sprite:
				_button_sprite.material = null
