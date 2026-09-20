@tool
class_name FacultyNameplate
extends Node2D
## Static wall nameplate for faculty doors. Not an interactable.
## Instance it, set plate_text, position = plate centre (220x52).

@export var plate_text: String = "Dr. Song":
	set(value):
		plate_text = value
		_apply_text()

@onready var _label: Label = $Plate/Face/Label


func _ready() -> void:
	_apply_text()


func _apply_text() -> void:
	if _label == null:
		_label = get_node_or_null("Plate/Face/Label")
	if _label != null:
		_label.text = plate_text
