# explanation_data.gd
extends Resource

class_name ExplanationData

## The node we want the spotlight to focus on.
@export var target_node_path: NodePath

## The lines of text that will be displayed one by one.
@export var explanation_lines: PackedStringArray

# You can still add more properties here later, like a title!
# @export var title: String
@export var exceptions_to_hide: Array[NodePath]
