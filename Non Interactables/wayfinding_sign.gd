@tool
class_name WayfindingSign
extends Node2D
## Directional wall sign at a room edge. Not an interactable.
## Instance it, set sign_text and arrow_direction, position = plate centre (340x60).

const ARROW_LEFT := "←"
const ARROW_RIGHT := "→"

@export var sign_text: String = "Somewhere":
	set(value):
		sign_text = value
		_apply()

## -1: arrow on the left pointing left. 1: arrow on the right pointing right. 0: no arrow.
@export_range(-1, 1) var arrow_direction: int = 1:
	set(value):
		arrow_direction = value
		_apply()

@onready var _label: Label = $Plate/Label


func _ready() -> void:
	_apply()


func _apply() -> void:
	if _label == null:
		_label = get_node_or_null("Plate/Label")
	if _label == null:
		return
	match arrow_direction:
		-1:
			_label.text = ARROW_LEFT + "  " + sign_text
		1:
			_label.text = sign_text + "  " + ARROW_RIGHT
		_:
			_label.text = sign_text
